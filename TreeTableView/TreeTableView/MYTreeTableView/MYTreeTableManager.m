//
//  MYTreeTableManager.m
//  MYTreeTableView
//
//  Created by mayan on 2018/4/3.
//  Copyright © 2018年 mayan. All rights reserved.
//

#import "MYTreeTableManager.h"
#import "MYTreeItem.h"

@interface MYTreeTableManager ()

@property (nonatomic, strong) NSDictionary *itemsMap;

@end

@implementation MYTreeTableManager


#pragma mark - Init

- (instancetype)initWithItems:(NSArray<MYTreeItem *> *)items andExpandLevel:(NSInteger)level
{
    self = [super init];
    if (self) {
        
        // 1. 建立 map
        NSMutableDictionary *itemsMap = [NSMutableDictionary dictionary];
        for (MYTreeItem *item in items) {
            [itemsMap setObject:item forKey:item.id];
        }
        self.itemsMap = itemsMap;
        
        // 2. 建立父子关系，并得到顶级节点
        NSMutableArray *topItems = [NSMutableArray array];
        for (MYTreeItem *item in items) {
            if ([item.parentId isKindOfClass:[NSNumber class]]) {
                MYTreeItem *parent = itemsMap[item.parentId];
                if (parent) {
                    item.parentItem = parent;
                    [parent.childItems addObject:item];
                }
            }
            if (!item.parentItem) {
                [topItems addObject:item];
            }
        }
        topItems = [topItems sortedArrayUsingComparator:^NSComparisonResult(MYTreeItem *obj1, MYTreeItem *obj2) {
            return [obj1.orderNo compare:obj2.orderNo];
        }].mutableCopy;
        
        // 3. 设置等级
        for (MYTreeItem *item in items) {
            int tmpLevel = 0;
            MYTreeItem *p = item.parentItem;
            while (p) {
                tmpLevel++;
                p = p.parentItem;
            }
            item.level = tmpLevel;
        }
        
        // 4. 根据展开等级设置 showItems
        NSMutableArray *showItems = [NSMutableArray array];
        for (MYTreeItem *item in topItems) {
            [self addItem:item toShowItems:showItems andAllowShowLevel:MAX(level, 0)];
        }
        _showItems = showItems;
        
    }
    return self;
}

- (void)addItem:(MYTreeItem *)item toShowItems:(NSMutableArray *)showItems andAllowShowLevel:(NSInteger)level {
    
    [showItems addObject:item];
    
    if (item.childItems.count && item.level < level) {
        
        item.isExpand = YES;
        item.childItems = [item.childItems sortedArrayUsingComparator:^NSComparisonResult(MYTreeItem *obj1, MYTreeItem *obj2) {
            return [obj1.orderNo compare:obj2.orderNo];
        }].mutableCopy;
        
        for (MYTreeItem *childItem in item.childItems) {
            [self addItem:childItem toShowItems:showItems andAllowShowLevel:level];
        }
    }
}


#pragma mark - Expand Item

// 展开/收起 Item，返回所改变的 Item 的个数
- (NSInteger)expandItem:(MYTreeItem *)item {
    return [self expandItem:item isExpand:!item.isExpand];
}

- (NSInteger)expandItem:(MYTreeItem *)item isExpand:(BOOL)isExpand {
    
    if (item.isExpand == isExpand) return 0;
    item.isExpand = isExpand;
    
    NSMutableArray *tmpArray = [NSMutableArray array];
    // 如果展开
    if (isExpand) {
        for (MYTreeItem *tmpItem in item.childItems) {
            [self addItem:tmpItem toTmpItems:tmpArray];
        }
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([self.showItems indexOfObject:item] + 1, tmpArray.count)];
        [self.showItems insertObjects:tmpArray atIndexes:indexSet];
    }
    // 如果折叠
    else {
        for (MYTreeItem *tmpItem in self.showItems) {
            
            BOOL isParent = NO;
            
            MYTreeItem *parentItem = tmpItem.parentItem;
            while (parentItem) {
                if (parentItem == item) {
                    isParent = YES;
                    break;
                }
                parentItem = parentItem.parentItem;
            }
            if (isParent) {
                [tmpArray addObject:tmpItem];
            }
        }
        [self.showItems removeObjectsInArray:tmpArray];
    }
    
    return tmpArray.count;
}
- (void)addItem:(MYTreeItem *)item toTmpItems:(NSMutableArray *)tmpItems {
    
    [tmpItems addObject:item];
    
    if (item.isExpand) {
        
        item.childItems = [item.childItems sortedArrayUsingComparator:^NSComparisonResult(MYTreeItem *obj1, MYTreeItem *obj2) {
            return [obj1.orderNo compare:obj2.orderNo];
        }].mutableCopy;
        
        for (MYTreeItem *tmpItem in item.childItems) {
            [self addItem:tmpItem toTmpItems:tmpItems];
        }
    }
}

/** 全部展开/全部折叠 */
- (void)expandAllItem:(BOOL)isExpand {
    
}


#pragma mark - Check Item

// 勾选/取消勾选 Item
- (void)checkItem:(MYTreeItem *)item {
    [self checkItem:item isCheck:!(item.checkState == MYTreeItemChecked)];
}

- (void)checkItem:(MYTreeItem *)item isCheck:(BOOL)isCheck {
    
    if (item.checkState == MYTreeItemChecked && isCheck) return;
    if (item.checkState == MYTreeItemDefault && !isCheck) return;
    
    // 勾选/取消勾选所有子 item
    [self checkChildItemWithItem:item isCheck:isCheck];
    // 刷新父 item 勾选状态
    [self refreshParentItemWithItem:item];
}
// 递归，勾选/取消勾选子 item
- (void)checkChildItemWithItem:(MYTreeItem *)item isCheck:(BOOL)isCheck {
    
    item.checkState = isCheck ? MYTreeItemChecked : MYTreeItemDefault;
    
    for (MYTreeItem *tmpItem in item.childItems) {
        [self checkChildItemWithItem:tmpItem isCheck:isCheck];
    }
}
// 递归，刷新父 item 勾选状态
- (void)refreshParentItemWithItem:(MYTreeItem *)item {
    
    NSInteger defaultNum = 0;
    NSInteger checkedNum = 0;
    
    for (MYTreeItem *tmpItem in item.parentItem.childItems) {
        
        switch (tmpItem.checkState) {
            case MYTreeItemDefault:
                defaultNum++;
                break;
            case MYTreeItemChecked:
                checkedNum++;
                break;
            case MYTreeItemHalfChecked:
                break;
        }
    }
    
    if (defaultNum == item.parentItem.childItems.count) {
        item.parentItem.checkState = MYTreeItemDefault;
    }
    else if (checkedNum == item.parentItem.childItems.count) {
        item.parentItem.checkState = MYTreeItemChecked;
    }
    else {
        item.parentItem.checkState = MYTreeItemHalfChecked;
    }
    
    if (item.parentItem) {
        [self refreshParentItemWithItem:item.parentItem];
    }
}

// 全部勾选/全部取消勾选
- (void)checkAllItem:(BOOL)isCheck {
    
    for (MYTreeItem *item in _showItems) {
        // 防止重复遍历
        if (item.level == 0) {
            [self checkChildItemWithItem:item isCheck:isCheck];
        }
    }
}

// 获取所有已经勾选的 Item
- (NSArray <MYTreeItem *>*)getAllCheckItem {
    
    NSMutableArray *tmpArray = [NSMutableArray array];
    
    for (MYTreeItem *item in _showItems) {
        // 防止重复遍历
        if (item.level == 0) {
            [self getAllCheckItem:tmpArray andItem:item];
        }
    }
    
    return tmpArray.copy;
}
// 递归，将已经勾选的 Item 添加到临时数组中
- (void)getAllCheckItem:(NSMutableArray <MYTreeItem *>*)tmpArray andItem:(MYTreeItem *)tmpItem {
    
    if (tmpItem.checkState == MYTreeItemDefault) return;
    if (tmpItem.checkState == MYTreeItemChecked) [tmpArray addObject:tmpItem];
    
    for (MYTreeItem *item in tmpItem.childItems) {
        [self getAllCheckItem:tmpArray andItem:item];
    }
}


#pragma mark - Other

// 根据 id 获取 item
- (MYTreeItem *)getItemWithItemId:(NSNumber *)itemId {
    
    if (!itemId) return nil;
    
    return self.itemsMap[itemId];
}


@end
