//
//  TBQuadTree.h
//  TBQuadTree
//
//  Created by Theodore Calmes on 9/19/13.
//  Copyright (c) 2013 Theodore Calmes. All rights reserved.
//



/*
 四叉树编码
 思路：把地理空间定量划分为可变大小的网格，每个网格具有相同的属性。
 原理：将二维区域按照四个象限进行递归分割，直到子象限的数值单调为止。
 
 是最有效的栅格数据压缩编码方法之一。其基本思想是首先把一幅图象或一幅栅格地图等分成四部分，如果检查到某个子区的所有格网都含有相同的值（灰度或属性值），那么这个子区域就不再往下分割；否则，把这个区域再分割成四个子区域，这样递归地分割，直至每个子块都只含有相同的灰度或属性值为止。
 */

#import <Foundation/Foundation.h>

// TBQuadTreeNodeData结构包含了坐标点(经度、纬度).   void*data是一个普通的指针，用来存储我们需要的其他信息，如旅馆名跟电话号码等
typedef struct TBQuadTreeNodeData {
    double x;
    double y;
    void* data;
} TBQuadTreeNodeData;
TBQuadTreeNodeData TBQuadTreeNodeDataMake(double x, double y, void* data);


//  TBBoundingBox代表一个用于范围查询的长方形，也就是之前谈到(xMin<=x<=xMax&&yMin<=y<=yMax)查询的那个长方形。左上角是(xMin,yMin)，右下角是(xMax,yMax)
typedef struct TBBoundingBox {
    double x0; double y0;
    double xf; double yf;
} TBBoundingBox;
TBBoundingBox TBBoundingBoxMake(double x0, double y0, double xf, double yf);


//  quadTreeNode 结构包含了四个指针，每个指针分别指向这个结点的四个子节点（将当前区域四等分后的四个区域，每个区域作为一个子节点）
typedef struct quadTreeNode {
    struct quadTreeNode* northWest;   //  子节点 之   左上角
    struct quadTreeNode* northEast;   //  子节点之   右上角
    struct quadTreeNode* southWest;  //  子节点之  左下角
    struct quadTreeNode* southEast;   //  子节点之  右下角
    TBBoundingBox boundingBox;     //  本节点所在区域矩形框
    int bucketCapacity;
    TBQuadTreeNodeData *points;
    int count;
} TBQuadTreeNode;
TBQuadTreeNode* TBQuadTreeNodeMake(TBBoundingBox boundary, int bucketCapacity);

void TBFreeQuadTreeNode(TBQuadTreeNode* node);

bool TBBoundingBoxContainsData(TBBoundingBox box, TBQuadTreeNodeData data);
bool TBBoundingBoxIntersectsBoundingBox(TBBoundingBox b1, TBBoundingBox b2);

typedef void(^TBQuadTreeTraverseBlock)(TBQuadTreeNode* currentNode);
void TBQuadTreeTraverse(TBQuadTreeNode* node, TBQuadTreeTraverseBlock block);

typedef void(^TBDataReturnBlock)(TBQuadTreeNodeData data);
void TBQuadTreeGatherDataInRange(TBQuadTreeNode* node, TBBoundingBox range, TBDataReturnBlock block);

bool TBQuadTreeNodeInsertData(TBQuadTreeNode* node, TBQuadTreeNodeData data);
TBQuadTreeNode* TBQuadTreeBuildWithData(TBQuadTreeNodeData *data, int count, TBBoundingBox boundingBox, int capacity);
