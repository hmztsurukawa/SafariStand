//
//  STVTabListCtl.m
//  SafariStand

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC
#endif

#import "SafariStand.h"
#import "STVTabListCtl.h"
#import "STTabProxy.h"
#import "STTabProxyController.h"
#import "HTUtils.h"
#import "STSafariConnect.h"
#import "HTWebKit2Adapter.h"
#import "STQuickSearchModule.h"

@interface STVTabListCtl ()

@end

@implementation STVTabListCtl
{
    BOOL _ignoreObserve;
}

+(STVTabListCtl*)viewCtl
{
    
    STVTabListCtl* result=[[STVTabListCtl alloc]initWithNibName:@"STVTabListCtl" bundle:
                          [NSBundle bundleWithIdentifier:kSafariStandBundleID]];
    
    return result;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)awakeFromNib
{
    [self.oTableView registerForDraggedTypes:@[STTABLIST_DRAG_ITEM_TYPE, @"public.url", @"public.file-url", NSStringPboardType]];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (void)setupWithTabView:(NSTabView*)tabView
{
    if(tabView)[self updateTabs:tabView];
    //[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(tabViewUpdatedZ:) name:STTabViewDidReplaceNote object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(tabViewUpdated:) name:STTabViewDidChangeNote object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(tabViewItemSelected:) name:STTabViewDidSelectItemNote object:nil];
    
}

- (void)uninstallFromTabView
{
    [self.tabs makeObjectsPerformSelector:@selector(uninstalledFromSidebar:) withObject:self];
}

- (void)updateTabs:(NSTabView*)tabView
{
    NSMutableArray *previousTabs=self.tabs;
    NSMutableArray *currentTabs=[STTabProxyController tabProxiesForTabView:tabView];
    for (STTabProxy* proxy in currentTabs) {
        [previousTabs removeObjectIdenticalTo:proxy];
        [proxy installedToSidebar:self];
    }
    
    //ここで残ってるのは閉じられたタブと移動中一時的に外されたタブ
    [previousTabs makeObjectsPerformSelector:@selector(uninstalledFromSidebar:) withObject:self];
    
    self.tabs=currentTabs;
    
}

- (void)tabViewUpdated:(NSNotification*)note
{
    NSTabView* tabView=[note object];
    //window 基準でチェックしてるので tabView ごと入れ替わっても大丈夫
    if (self.view.window==[tabView window]) {
        [self updateTabs:tabView];
    }
}

- (void)tabViewItemSelected:(NSNotification*)note
{
    NSTabView* tabView=[note object];
    if (self.view.window==[tabView window]) {
        //もうちょっとうまい方法はあるだろうけど
        [self.oTableView reloadData];
    }
}

- (void)takeSelectionFromTabView:(NSTabView*)tabView
{
    NSTabViewItem *itm=[tabView selectedTabViewItem];
    STTabProxy* proxy=[STTabProxy tabProxyForTabViewItem:itm];
    if (proxy) {
        BOOL prevObserve=_ignoreObserve;
        //NSUInteger idx=[self.tabs indexOfObject:proxy];
        _ignoreObserve=YES;

        
        _ignoreObserve=prevObserve;
    }
}

#pragma mark - tableView

- (IBAction)actTableViewClicked:(id)sender
{
    NSInteger clickedIndex=[self.oTableView clickedRow];
    if (clickedIndex>=0) {
        STTabProxy* tabProxy=[self.tabs objectAtIndex:clickedIndex];
        [tabProxy selectTab];
        return;
    }else if ([[NSApp currentEvent]clickCount]==2) {
        [NSApp sendAction:@selector(newTab:) to:nil from:nil];
    }
}

#pragma mark - menu

- (IBAction)actGoToClipboard:(id)sender
{
    NSURL* url=[sender representedObject];

    //tab will created in frontmost window
    if (url) {
        STSafariGoToURLWithPolicy(url, poNewTab);
    }
}

- (NSMenu*)menuForEmptyTarget
{
    NSMenu* menu=[[NSMenu alloc]initWithTitle:@""];
    NSMenuItem* itm;
    NSMenuItem* separator=nil;

    //tab will created in frontmost window
    itm=[menu addItemWithTitle:@"New Tab" action:@selector(newTab:) keyEquivalent:@""];
    itm=[menu addItemWithTitle:@"Move Sidebar To Far Side" action:@selector(STToggleSidebarLR:) keyEquivalent:@""];
    
    separator=[NSMenuItem separatorItem];
    
    //goToClipboard
    NSURL* url=HTBestURLFromPasteboard([NSPasteboard generalPasteboard], YES);
    //BOOL goToClipboardMenuItemShown=NO;
    if (url) {
        NSString* title=LOCALIZE(@"Go To \"%@\"");
        NSString* urlStr=[url absoluteString];
        if ([urlStr length]>42) {
            urlStr=[[urlStr substringToIndex:39]stringByAppendingString:@"..."];
        }

        title=[NSString stringWithFormat:title, urlStr];
        if (separator) {
            [menu addItem:separator];
            separator=nil;
        }
        itm=[menu addItemWithTitle:title action:@selector(actGoToClipboard:) keyEquivalent:@""];
        [itm setTarget:self];
        [itm setRepresentedObject:url];
    
    //search Clipboard
    }else{
        NSPasteboard* pb=[NSPasteboard generalPasteboard];
        NSString* searchString=[[pb stringForType:NSStringPboardType]htModeratedStringWithin:255];
        NSMenu* qsMenu=nil;
        if([searchString length]){
            qsMenu=[[STQuickSearchModule si]standardQuickSearchMenuWithSearchString:searchString];
        }
        if (qsMenu) {
            NSString* title=LOCALIZE(@"Search \"%@\"");
            if ([searchString length]>42) {
                searchString=[[searchString substringToIndex:39]stringByAppendingString:@"..."];
            }
            title=[NSString stringWithFormat:title, searchString];
            if (separator) {
                [menu addItem:separator];
                separator=nil;
            }
            itm=[menu addItemWithTitle:title action:nil keyEquivalent:@""];
            [itm setSubmenu:qsMenu];
        }
    }
    
    return menu;
}

- (NSMenu*)menuForTabProxy:(STTabProxy*)tabProxy
{
    if (!tabProxy){
        return [self menuForEmptyTarget];
    }

    NSMenu* menu=[[NSMenu alloc]initWithTitle:@""];
    NSMenuItem* itm;
    NSMenuItem* separator=nil;
    
    itm=[menu addItemWithTitle:@"Close Tab" action:@selector(actClose:) keyEquivalent:@""];
    [itm setTarget:tabProxy];
    
    if ([tabProxy isThereOtherTab]) {
        itm=[menu addItemWithTitle:@"Close Other Tab" action:@selector(actCloseOther:) keyEquivalent:@""];
        [itm setTarget:tabProxy];
        
        itm=[menu addItemWithTitle:@"Move Tab To New Window" action:@selector(actMoveTabToNewWindow:) keyEquivalent:@""];
        [itm setTarget:tabProxy];
    }
    
    separator=[NSMenuItem separatorItem];
    
    if (STSafariCanReloadTab([tabProxy tabViewItem])) {
        if (separator) {
            [menu addItem:separator];
            separator=nil;
        }
        itm=[menu addItemWithTitle:@"Reload Tab" action:@selector(actReload:) keyEquivalent:@""];
        [itm setTarget:tabProxy];
        
        separator=[NSMenuItem separatorItem];
    }
    
    if (separator) {
        [menu addItem:separator];
        separator=nil;
    }
    itm=[menu addItemWithTitle:@"Move Sidebar To Far Side" action:@selector(STToggleSidebarLR:) keyEquivalent:@""];
    
    return menu;
}

- (NSMenu*)menuForTabListTableView:(STVTabListTableView*)listView row:(NSInteger)row
{
    if (row==-1) {
        return [self menuForEmptyTarget];
    } else if ([self.tabs count]>row) {
        STTabProxy* tabProxy=[self.tabs objectAtIndex:row];
        return [self menuForTabProxy:tabProxy];
    }
    return nil;
}

#pragma mark - drag and drop

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    [pboard declareTypes:@[STTABLIST_DRAG_ITEM_TYPE] owner:self];
    
    NSMutableArray* ary=[[NSMutableArray alloc]initWithCapacity:[rowIndexes count]];
    NSUInteger currentIndex = [rowIndexes firstIndex];
    while (currentIndex != NSNotFound) {
        [ary addObject:@(currentIndex)];
        currentIndex = [rowIndexes indexGreaterThanIndex:currentIndex];
    }
    [pboard setPropertyList:ary forType:STTABLIST_DRAG_ITEM_TYPE];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if (operation==NSTableViewDropOn) {
        return NSDragOperationNone;
    }
    
    NSArray *dragTypes = [[info draggingPasteboard]types];
    if([dragTypes containsObject:STTABLIST_DRAG_ITEM_TYPE]){
        return NSDragOperationMove;
    }
    
    
    NSURL *aURL=HTBestURLFromPasteboard([info draggingPasteboard], NO);
    if (aURL) {
        return NSDragOperationCopy;
    }

    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id < NSDraggingInfo >)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    if (operation==NSTableViewDropOn) {
        return NO;
    }
    
    BOOL acceptDrop = NO;
    NSPasteboard *pb=[info draggingPasteboard];
    NSArray *dragTypes = [pb types];
    
    if ([dragTypes containsObject:STTABLIST_DRAG_ITEM_TYPE]) {
        acceptDrop = YES;
        
        id sender=[info draggingSource]; //NSTableView
        NSArray *indexes = [pb propertyListForType:STTABLIST_DRAG_ITEM_TYPE];

        //drag from same view
        if (sender==aTableView) {
            _ignoreObserve=YES;
            NSMutableArray* aboveArray=[NSMutableArray array];
            NSMutableArray* insertedArray=[NSMutableArray array];
            NSMutableArray* belowArray=[NSMutableArray array];
            
            NSInteger i;
            NSInteger cnt=[self.tabs count];
            for (i=0; i<cnt; i++) {
                STTabProxy* tabProxy=[self.tabs objectAtIndex:i];
                if ([indexes containsObject:[NSNumber numberWithInteger:i]]) {
                    [insertedArray addObject:tabProxy];
                }else if (i<row) {
                    [aboveArray addObject:tabProxy];
                }else{
                    [belowArray addObject:tabProxy];
                }
            }
            [aboveArray addObjectsFromArray:insertedArray];
            [aboveArray addObjectsFromArray:belowArray];
            cnt=[aboveArray count];
            for (i=0; i<cnt; i++) {
                STTabProxy* tabProxy=[aboveArray objectAtIndex:i];
                
                STSafariMoveTabViewItemToIndex(tabProxy.tabViewItem, i);
            }
            _ignoreObserve=NO;
            self.tabs=aboveArray;
            
        //drag from other view
        }else if([[sender dataSource]isKindOfClass:[STVTabListCtl class]]) {
            STVTabListCtl* draggedCtl=(STVTabListCtl*)[sender dataSource];
            NSEnumerator* e=[indexes reverseObjectEnumerator];
            NSNumber* index;
            while (index=[e nextObject]) {
                STTabProxy* draggedProxy=[draggedCtl.tabs objectAtIndex:[index integerValue]];
                STSafariMoveTabToOtherWindow(draggedProxy.tabViewItem, [aTableView window], row, YES);
            }
        }
    //drag other element
    } else {
        NSURL *urlToGo=HTBestURLFromPasteboard([info draggingPasteboard], YES);
        if (urlToGo) {
            acceptDrop = YES;
            
            _ignoreObserve=YES;
            
            id newTabItem=STSafariCreateWKViewOrWebViewAtIndexAndShow([aTableView window], row, YES);
            if(newTabItem){
                STTabProxy* newProxy=[STTabProxy tabProxyForTabViewItem:newTabItem];
                [newProxy goToURL:urlToGo];
            }
            _ignoreObserve=NO;
            [self updateTabs:[newTabItem tabView]];
        }
    }

    return acceptDrop;

}

@end


#pragma mark - Support Classes


@implementation STVTabListTableView

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	NSInteger row = [self rowAtPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
    
    return [self.oTabListCtl menuForTabListTableView:self row:row];
}

@end



@implementation STVTabListCellView

- (IBAction)actCloseBtn:(id)sender
{
    STTabProxy* tabProxy=[self objectValue];
    [tabProxy actClose:self];
}

-(void)drawRect:(NSRect)dirtyRect
{
    STTabProxy* tabProxy=[self objectValue];
    if (tabProxy.isSelected) {

        static NSColor* borderColor=nil;
        if (!borderColor) {
            borderColor=[NSColor colorWithCalibratedRed:1.0f/255.0f green:100.0f/255.0f blue:205.0f/255.0f alpha:1.0];
        }
        [borderColor setStroke];
        
        NSShadow* shadow=[[NSShadow alloc]init];
        [shadow setShadowColor:borderColor];
        [shadow setShadowBlurRadius:2.0];
        [shadow set];
        
        NSBezierPath *bp=[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:5 yRadius:5];
        [bp setLineWidth:5.0f];
        [bp stroke];
        
    }else{
    
        [[NSColor lightGrayColor] setStroke];
        [NSBezierPath setDefaultLineWidth:0.0f];
        [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(self.bounds), NSMinY(self.bounds))
                              toPoint:NSMakePoint(NSMaxX(self.bounds), NSMinY(self.bounds))];
    }
}

@end



@implementation STVTabListButton

@end



@implementation STVTabListButtonCell

-(void)awakeFromNib
{
    NSImage* image=[self image];

    NSImage* lightImage=({
        NSImage* lightImage=[[NSImage alloc]initWithSize:[image size]];
        [lightImage lockFocus];
        NSRect rect=NSZeroRect;
        rect.size=[image size];
        [image drawAtPoint:NSZeroPoint fromRect:rect operation:NSCompositeCopy fraction:0.33];
        [lightImage unlockFocus];
        lightImage;
    });
    
    [self setAlternateImage:image];
    [self setImage:lightImage];
    
}

@end
