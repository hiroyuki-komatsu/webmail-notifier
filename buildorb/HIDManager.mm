//
//  HIDManager.m
//  buildorb
//
//  Created by Hiroyuki Komatsu on 2012/11/14.
//
//

#import "HIDManager.h"

namespace {
  NSInteger CompareDeviceRef(id device1, id device2, void *context) {
    const int comp = ([[(id<HIDDeviceProtocol>)device1 getLocationID] intValue] -
                      [[(id<HIDDeviceProtocol>)device2 getLocationID] intValue]);
    if (comp < 0) {
      return NSOrderedAscending;
    } else if (comp > 0) {
      return NSOrderedDescending;
    } else {
      return NSOrderedSame;
    }
  }
}  // namespace

@implementation HIDManager
- (id)init {
  self = [super init];
  if (self != nil) {
    managerRef_ = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    IOHIDManagerScheduleWithRunLoop(managerRef_,
                                    CFRunLoopGetMain(),
                                    kCFRunLoopDefaultMode);
    const IOReturn result = IOHIDManagerOpen(managerRef_, kIOHIDOptionsTypeNone);
    if (result != kIOReturnSuccess) {
      NSLog(@"Failed IOHIDManagerOpen.");
    }
  }
  return self;
}

- (void)dealloc {
  CFRelease(managerRef_);
  [super dealloc];
}

- (IOHIDManagerRef)managerRef {
  return managerRef_;
}

- (NSArray *)getDevicesWithVendorID:(int)vendorID productID:(int)productID {
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                        // Vendor ID
                        [NSNumber numberWithInt:vendorID],
                        @kIOHIDVendorIDKey,
                        // Product ID
                        [NSNumber numberWithInt:productID],
                        @kIOHIDProductIDKey,
                        nil];
  
  IOHIDManagerSetDeviceMatching(managerRef_, (CFDictionaryRef)dict);
  
  NSSet *deviceSet = (NSSet *)IOHIDManagerCopyDevices(managerRef_);
  
  NSEnumerator *setEnum = [deviceSet objectEnumerator];
  NSMutableArray *deviceArray = [[NSMutableArray alloc] init];
  IOHIDDeviceRef deviceRef;
  while ((deviceRef = (IOHIDDeviceRef)[setEnum nextObject]) != nil) {
    [deviceArray addObject:[[HIDDevice alloc]
                            initWithIOHIDDeviceRef:deviceRef]];
  }
  NSArray *sortedArray = [deviceArray
                          sortedArrayUsingFunction:CompareDeviceRef
                          context:NULL];
  return sortedArray;
}
@end

@implementation HIDDevice
- (id)initWithIOHIDDeviceRef: (IOHIDDeviceRef)device {
  self = [super init];
  if (self != nil) {
    deviceRef_ = device;
  }
  return self;
}

- (IOHIDDeviceRef)deviceRef {
  return deviceRef_;
}

- (BOOL)open {
  const IOReturn result = IOHIDDeviceOpen(deviceRef_, kIOHIDOptionsTypeNone);
  return (result == kIOReturnSuccess);
}

- (BOOL)close {
  const IOReturn result = IOHIDDeviceClose(deviceRef_, kIOHIDOptionsTypeNone);
  return (result == kIOReturnSuccess);
}

- (NSNumber *)getNumberProperty:(NSString *)key {
  if (!IOHIDDeviceGetTypeID() == CFGetTypeID(deviceRef_)) {
    return nil;
  }
  
  CFTypeRef cftypeRef = IOHIDDeviceGetProperty(deviceRef_, (CFStringRef)key);
  if (!cftypeRef ||
      CFNumberGetTypeID() != CFGetTypeID(cftypeRef)) {
    return nil;
  }
  
  return (NSNumber *)cftypeRef;
}

- (NSNumber *)getLocationID {
  return [self getNumberProperty:
          [NSString stringWithCString:kIOHIDLocationIDKey
                             encoding:NSUTF8StringEncoding]];
}

- (BOOL)setReport:(int)reportID output:(NSData *)data {
  const IOReturn result = IOHIDDeviceSetReport(deviceRef_, kIOHIDReportTypeOutput, reportID, (const uint8_t *)[data bytes], [data length]);
  return (result == kIOReturnSuccess);
}
@end
