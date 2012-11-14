//
//  WebmailNotifierProtocol.h
//  buildorb
//
//  Created by Hiroyuki Komatsu on 2012/11/14.
//
//

#import <Foundation/Foundation.h>

@protocol HIDManagerProtocol <NSObject>
- (id)init;
- (void)dealloc;
// Returns an array of HIDDeviceProtocol objects.
- (NSArray *) getDevicesWithVendorID: (int)vendorID productID:(int)productID;
@end


@protocol HIDDeviceProtocol <NSObject>
- (id)initWithIOHIDDeviceRef: (IOHIDDeviceRef)device;
- (BOOL)open;
- (BOOL)close;
- (NSNumber *)getNumberProperty: (NSString *)key;
- (NSNumber *)getLocationID;
- (BOOL)setReport: (int)reportID output:(NSData *)data;
@end
