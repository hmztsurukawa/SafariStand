//
//  STCModule.h
//  SafariStand



#import <Foundation/Foundation.h>


@interface STCModule : NSObject

- (id)initWithStand:(id)core;

- (void)prefValue:(NSString*)key changed:(id)value;
- (void)observePrefValue:(NSString*)key;

- (void)modulesDidFinishLoading:(id)core;
@end
