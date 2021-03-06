//
//  STCTabWithToolbarWinCtl.h
//  SafariStand


#import <Cocoa/Cocoa.h>


@interface STCTabWithToolbarWinCtl : NSWindowController

@property (nonatomic, weak) IBOutlet NSToolbar* oToolbar;
@property (nonatomic, weak) IBOutlet NSTabView* oTabView;

-(void)addIdentifier:(NSString*)identifier;

- (IBAction)actToolbarClick:(id)sender;
-(void)addPane:(NSView*)view withIdentifier:(NSString*)identifier title:(NSString*)title icon:(NSImage*)icon;

@end
