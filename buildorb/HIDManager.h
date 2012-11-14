//
//  WebmailNotifier.h
//  buildorb
//
//  Created by Hiroyuki Komatsu on 2012/11/13.
//
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>

#import "HIDManagerProtocol.h"

@interface HIDManager : NSObject <HIDManagerProtocol> {
@private
  IOHIDManagerRef managerRef_;
}
- (IOHIDManagerRef)managerRef;
@end

@interface HIDDevice : NSObject <HIDDeviceProtocol> {
@private
  IOHIDDeviceRef deviceRef_;
}
- (IOHIDDeviceRef)deviceRef;
@end

