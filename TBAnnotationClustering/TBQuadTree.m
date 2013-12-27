//
//  TBQuadTree.m
//  TBQuadTree
//
//  Created by Theodore Calmes on 9/19/13.
//  Copyright (c) 2013 Theodore Calmes. All rights reserved.
//

#import "TBQuadTree.h"

#pragma mark - Constructors
/**
 *  创建  TBQuadTreeNodeData  坐标点
 *
 *  @param x    x坐标
 *  @param y     y 坐标
 *  @param data  数据指针
 *
 *  @return   TBQuadTreeNodeData
 */
TBQuadTreeNodeData TBQuadTreeNodeDataMake(double x, double y, void* data)
{
    TBQuadTreeNodeData d; d.x = x; d.y = y; d.data = data;
    return d;
}



/**
 *  创建  TBBoundingBox   给定区域范围
 *
 *  @param x0  矩形框的四个点之一
 *  @param y0  矩形框的四个点之二
 *  @param xf   矩形框的四个点之三
 *  @param yf   矩形框的四个点之四
 *
 *  @return      TBBoundingBox
 */
TBBoundingBox TBBoundingBoxMake(double x0, double y0, double xf, double yf)
{
    TBBoundingBox bb; bb.x0 = x0; bb.y0 = y0; bb.xf = xf; bb.yf = yf;
    return bb;
}


/**
 *  创建 TBQuadTreeNode 四叉树节点
 *
 *  @param boundary       矩形区域
 *  @param bucketCapacity 子节点容量
 *
 *  @return   TBQuadTreeNode  四叉树节点
 */
TBQuadTreeNode* TBQuadTreeNodeMake(TBBoundingBox boundary, int bucketCapacity)
{
    TBQuadTreeNode* node = malloc(sizeof(TBQuadTreeNode));  // 向系统申请分配空间
    //   四个子节点 初始化 为NULL
    node->northWest = NULL;
    node->northEast = NULL;
    node->southWest = NULL;
    node->southEast = NULL;

    node->boundingBox = boundary; //  矩形区域
    node->bucketCapacity = bucketCapacity;   //  子节点容量
    node->count = 0;  //  子节点索引
    node->points = malloc(sizeof(TBQuadTreeNodeData) * bucketCapacity);  //  申请分配内存空间    由于每个子节点都有可能包含一个  TBQuadTreeNodeData

    return node;
}

#pragma mark - Bounding Box Functions
/**
 *  判断给定的坐标是否包含在矩形框内
 *
 *  @param box  矩形边框（某个节点）
 *  @param data  坐标点
 *
 *  @return   bool   true/false
 */
bool TBBoundingBoxContainsData(TBBoundingBox box, TBQuadTreeNodeData data)
{
    bool containsX = box.x0 <= data.x && data.x <= box.xf;
    bool containsY = box.y0 <= data.y && data.y <= box.yf;

    return containsX && containsY;
}

/**
 *  判断 矩形b2 是否包含在 b1内部
 *
 *  @param b1  矩形区域B1
 *  @param b2  矩形区域B2
 *
 *  @return bool   true/false
 */
bool TBBoundingBoxIntersectsBoundingBox(TBBoundingBox b1, TBBoundingBox b2)
{
    return (b1.x0 <= b2.xf && b1.xf >= b2.x0 && b1.y0 <= b2.yf && b1.yf >= b2.y0);
}


#pragma mark - Quad Tree Functions

/**
 *     生成四叉树,完成四叉树构造
 *
 *  @param node  给定的节点
 */
void TBQuadTreeNodeSubdivide(TBQuadTreeNode* node)
{
    TBBoundingBox box = node->boundingBox;  //  获取给定节点的矩形框
    
    //  获取矩形框的中间点坐标
    double xMid = (box.xf + box.x0) / 2.0;
    double yMid = (box.yf + box.y0) / 2.0;

    //  生成四个子节点
    TBBoundingBox northWest = TBBoundingBoxMake(box.x0, box.y0, xMid, yMid);
    node->northWest = TBQuadTreeNodeMake(northWest, node->bucketCapacity);

    TBBoundingBox northEast = TBBoundingBoxMake(xMid, box.y0, box.xf, yMid);
    node->northEast = TBQuadTreeNodeMake(northEast, node->bucketCapacity);

    TBBoundingBox southWest = TBBoundingBoxMake(box.x0, yMid, xMid, box.yf);
    node->southWest = TBQuadTreeNodeMake(southWest, node->bucketCapacity);

    TBBoundingBox southEast = TBBoundingBoxMake(xMid, yMid, box.xf, box.yf);
    node->southEast = TBQuadTreeNodeMake(southEast, node->bucketCapacity);
}

/**
 *  判断坐标点是否属于某个节点
 *
 *  @param node 节点
 *  @param data 坐标点
 *
 *  @return bool  true/false
 */
bool TBQuadTreeNodeInsertData(TBQuadTreeNode* node, TBQuadTreeNodeData data)
{
     //  首先判断 坐标点是否包含在给定节点所在的矩形范围内
    if (!TBBoundingBoxContainsData(node->boundingBox, data)) {
        return false;
    }
 
    if (node->count < node->bucketCapacity) {
        node->points[node->count++] = data;
        return true;
    }

    //  生成四叉树
    if (node->northWest == NULL) {
        TBQuadTreeNodeSubdivide(node);
    }

    //  递归 调用
    if (TBQuadTreeNodeInsertData(node->northWest, data)) return true;
    if (TBQuadTreeNodeInsertData(node->northEast, data)) return true;
    if (TBQuadTreeNodeInsertData(node->southWest, data)) return true;
    if (TBQuadTreeNodeInsertData(node->southEast, data)) return true;

    return false;
}

/**
 *   在四叉树上进行区域范围查询
 *
 *  @param node   节点
 *  @param range  范围
 *  @param block    TBDataReturnBlock  块
 */

void TBQuadTreeGatherDataInRange(TBQuadTreeNode* node, TBBoundingBox range, TBDataReturnBlock block)
{
    // 范围查询
    if (!TBBoundingBoxIntersectsBoundingBox(node->boundingBox, range)) {
        return;
    }
   
    //  遍历节点中所有坐标点，查询坐标点是否在特定的范围
    for (int i = 0; i < node->count; i++) {
        if (TBBoundingBoxContainsData(range, node->points[i])) {
            block(node->points[i]);
        }
    }

    if (node->northWest == NULL) {
        return;
    }
   
    //  递归  查询
    TBQuadTreeGatherDataInRange(node->northWest, range, block);
    TBQuadTreeGatherDataInRange(node->northEast, range, block);
    TBQuadTreeGatherDataInRange(node->southWest, range, block);
    TBQuadTreeGatherDataInRange(node->southEast, range, block);
}

void TBQuadTreeTraverse(TBQuadTreeNode* node, TBQuadTreeTraverseBlock block)
{
    block(node);

    if (node->northWest == NULL) {
        return;
    }

    TBQuadTreeTraverse(node->northWest, block);
    TBQuadTreeTraverse(node->northEast, block);
    TBQuadTreeTraverse(node->southWest, block);
    TBQuadTreeTraverse(node->southEast, block);
}

/**
 *  用数据填充四叉树
 *
 *  @param data        坐标点
 *  @param count       坐标点索引
 *  @param boundingBox  四叉树范围
 *  @param capacity    子节点容量
 *
 *  @return    TBQuadTreeNode 四叉树节点
 */
TBQuadTreeNode* TBQuadTreeBuildWithData(TBQuadTreeNodeData *data, int count, TBBoundingBox boundingBox, int capacity)
{
    TBQuadTreeNode* root = TBQuadTreeNodeMake(boundingBox, capacity);
    for (int i = 0; i < count; i++) {
        TBQuadTreeNodeInsertData(root, data[i]);
    }

    return root;
}


/**
 *  释放内存
 *
 *  @param node  节点
 */
void TBFreeQuadTreeNode(TBQuadTreeNode* node)
{
    if (node->northWest != NULL) TBFreeQuadTreeNode(node->northWest);
    if (node->northEast != NULL) TBFreeQuadTreeNode(node->northEast);
    if (node->southWest != NULL) TBFreeQuadTreeNode(node->southWest);
    if (node->southEast != NULL) TBFreeQuadTreeNode(node->southEast);

    for (int i=0; i < node->count; i++) {
        free(node->points[i].data);
    }
    free(node->points);
    free(node);
}
