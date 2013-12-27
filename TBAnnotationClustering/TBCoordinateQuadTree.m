//
//  TBCoordinateQuadTree.m
//  TBAnnotationClustering
//
//  Created by Theodore Calmes on 9/27/13.
//  Copyright (c) 2013 Theodore Calmes. All rights reserved.
//

#import "TBCoordinateQuadTree.h"
#import "TBClusterAnnotation.h"

//  旅馆信息的结构体
typedef struct TBHotelInfo {
    char* hotelName;  // 旅馆名称
    char* hotelPhoneNumber;   // 旅馆电话号码
} TBHotelInfo;


/**
 *  生成坐标点。即将旅馆信息 储存进 TBQuadTreeNodeData 结构体,包括旅馆经纬度、旅馆名称、旅馆电话
 *
 *  @param line  旅馆信息的字符串
 *
 *  @return   TBQuadTreeNodeData 结构体
 */
TBQuadTreeNodeData TBDataFromLine(NSString *line)
{
    NSArray *components = [line componentsSeparatedByString:@","];
    double latitude = [components[1] doubleValue];  //  纬度
    double longitude = [components[0] doubleValue];  // 经度

    TBHotelInfo* hotelInfo = malloc(sizeof(TBHotelInfo)); // 申请分配空间

    NSString *hotelName = [components[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    hotelInfo->hotelName = malloc(sizeof(char) * hotelName.length + 1);
    
    
    /*
     char * strncpy( char *dest, char *src, size_t num );     (c/c++）复制src中的内容（字符，数字、汉字....）到dest，复制多少由num的值决定，返回指向dest的指针
     说明：
     如果n > dest串长度，dest栈空间溢出产生崩溃异常。
     否则：
     1）src串长度<=dest串长度,(这里的串长度包含串尾NULL字符)
     如果n<src串长度，src的前n个字符复制到dest中。但是由于没有NULL字符，所以直接访问dest串会发生栈溢出的异常情况。
     如果n = src串长度，与strcpy一致。
     如果n >src串长度，src串存放于dest字串的[0,src串长度]，dest串的(src串长度, dest串长度]处存放NULL。
     2）src串长度>dest串长度
     如果n =dest串长度，则dest串没有NULL字符，会导致输出会有乱码。如果不考虑src串复制完整性，可以将dest 最后一字符置为NULL。
     
     综上，一般情况下，使用strncpy时，建议将n置为dest串长度（除非你将多个src串都复制到dest数组，并且从dest尾部反向操作)，复制完毕后，为保险起见，将dest串最后一字符置NULL，避免发生在第2)种情况下的输出乱码问题。当然喽，无论是strcpy还是strncpy，保证src串长度<dest串长度才是最重要的。
     */
    
    //  通过strncpy 函数为结构体 赋值   旅馆名称
    strncpy(hotelInfo->hotelName, [hotelName UTF8String], hotelName.length + 1);

    
    NSString *hotelPhoneNumber = [[components lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    hotelInfo->hotelPhoneNumber = malloc(sizeof(char) * hotelPhoneNumber.length + 1);
    
    // 旅馆电话
    strncpy(hotelInfo->hotelPhoneNumber, [hotelPhoneNumber UTF8String], hotelPhoneNumber.length + 1);

    return TBQuadTreeNodeDataMake(latitude, longitude, hotelInfo);   // 生成坐标
}

/**
 *   利用地图区域  生成TBBoundingBox
 *
 *  @param mapRect   地图区域
 *
 *  @return   TBBoundingBox
 */
TBBoundingBox TBBoundingBoxForMapRect(MKMapRect mapRect)
{
    //  从地图的区域得到 TBBoundingBox结构体的四个顶点
    CLLocationCoordinate2D topLeft = MKCoordinateForMapPoint(mapRect.origin);//  地图的左上角  经纬度
    CLLocationCoordinate2D botRight = MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMaxX(mapRect), MKMapRectGetMaxY(mapRect))); // 地图的右下角经纬度

    //  CLLocationDegrees    WGS 84坐标系下的坐标
    CLLocationDegrees minLat = botRight.latitude;
    CLLocationDegrees maxLat = topLeft.latitude;

    CLLocationDegrees minLon = topLeft.longitude;
    CLLocationDegrees maxLon = botRight.longitude;

    return TBBoundingBoxMake(minLat, minLon, maxLat, maxLon);
}

/**
 *  将TBBoundingBox 转化成地图上的区域
 *
 *  @param boundingBox    四叉树节点的区域
 *
 *  @return  MKMapRect  地图上的区域
 */
MKMapRect TBMapRectForBoundingBox(TBBoundingBox boundingBox)
{
    MKMapPoint topLeft = MKMapPointForCoordinate(CLLocationCoordinate2DMake(boundingBox.x0, boundingBox.y0));
    MKMapPoint botRight = MKMapPointForCoordinate(CLLocationCoordinate2DMake(boundingBox.xf, boundingBox.yf));

    return MKMapRectMake(topLeft.x, botRight.y, fabs(botRight.x - topLeft.x), fabs(botRight.y - topLeft.y));
}


NSInteger TBZoomScaleToZoomLevel(MKZoomScale scale)
{
    double totalTilesAtMaxZoom = MKMapSizeWorld.width / 256.0;
    NSInteger zoomLevelAtMaxZoom = log2(totalTilesAtMaxZoom);
    NSInteger zoomLevel = MAX(0, zoomLevelAtMaxZoom + floor(log2f(scale) + 0.5));

    return zoomLevel;
}

float TBCellSizeForZoomScale(MKZoomScale zoomScale)
{
    NSInteger zoomLevel = TBZoomScaleToZoomLevel(zoomScale);

    switch (zoomLevel) {
        case 13:
        case 14:
        case 15:
            return 64;
        case 16:
        case 17:
        case 18:
            return 32;
        case 19:
            return 16;

        default:
            return 88;
    }
}

@implementation TBCoordinateQuadTree

/**
 *  获取所有旅馆数据,将数据填充至四叉树节点
 */
- (void)buildTree
{
    @autoreleasepool {
        //  从USA-HotelMotel.csv文件中获取旅馆数据
        NSString *data = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"USA-HotelMotel" ofType:@"csv"] encoding:NSASCIIStringEncoding error:nil];
        NSArray *lines = [data componentsSeparatedByString:@"\n"];
        NSInteger count = lines.count - 1;
      
        //
        TBQuadTreeNodeData *dataArray = malloc(sizeof(TBQuadTreeNodeData) * count);
        for (NSInteger i = 0; i < count; i++) {
            dataArray[i] = TBDataFromLine(lines[i]);
        }

        TBBoundingBox world = TBBoundingBoxMake(19, -166, 72, -53);
        _root = TBQuadTreeBuildWithData(dataArray, (int)count, world, 4);
    }
}

- (NSArray *)clusteredAnnotationsWithinMapRect:(MKMapRect)rect withZoomScale:(double)zoomScale
{
    double TBCellSize = TBCellSizeForZoomScale(zoomScale);
    double scaleFactor = zoomScale / TBCellSize;

    NSInteger minX = floor(MKMapRectGetMinX(rect) * scaleFactor);
    NSInteger maxX = floor(MKMapRectGetMaxX(rect) * scaleFactor);
    NSInteger minY = floor(MKMapRectGetMinY(rect) * scaleFactor);
    NSInteger maxY = floor(MKMapRectGetMaxY(rect) * scaleFactor);

    NSMutableArray *clusteredAnnotations = [[NSMutableArray alloc] init];
    for (NSInteger x = minX; x <= maxX; x++) {
        for (NSInteger y = minY; y <= maxY; y++) {
            MKMapRect mapRect = MKMapRectMake(x / scaleFactor, y / scaleFactor, 1.0 / scaleFactor, 1.0 / scaleFactor);
            
            __block double totalX = 0;
            __block double totalY = 0;
            __block int count = 0;

            NSMutableArray *names = [[NSMutableArray alloc] init];
            NSMutableArray *phoneNumbers = [[NSMutableArray alloc] init];

            TBQuadTreeGatherDataInRange(self.root, TBBoundingBoxForMapRect(mapRect), ^(TBQuadTreeNodeData data) {
                totalX += data.x;
                totalY += data.y;
                count++;

                TBHotelInfo hotelInfo = *(TBHotelInfo *)data.data;
                [names addObject:[NSString stringWithFormat:@"%s", hotelInfo.hotelName]];
                [phoneNumbers addObject:[NSString stringWithFormat:@"%s", hotelInfo.hotelPhoneNumber]];
            });

            if (count == 1) {
                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(totalX, totalY);
                TBClusterAnnotation *annotation = [[TBClusterAnnotation alloc] initWithCoordinate:coordinate count:count];
                annotation.title = [names lastObject];
                annotation.subtitle = [phoneNumbers lastObject];
                [clusteredAnnotations addObject:annotation];
            }

            if (count > 1) {
                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(totalX / count, totalY / count);
                TBClusterAnnotation *annotation = [[TBClusterAnnotation alloc] initWithCoordinate:coordinate count:count];
                [clusteredAnnotations addObject:annotation];
            }
        }
    }

    return [NSArray arrayWithArray:clusteredAnnotations];
}

@end
