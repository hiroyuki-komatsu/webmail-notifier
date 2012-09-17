//
//  main.m
//  buildorb
//
//  Created by Hiroyuki Komatsu on 9/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>

#include <stdio.h>
#include <stdlib.h>

@interface HIDManager : NSObject {
@private
  IOHIDManagerRef managerRef_;  
}

- (id)init;
- (void)dealloc;
- (IOHIDManagerRef)managerRef;
- (NSArray *) getDevicesWithVendorID: (int)vendorID productID:(int)productID;
@end


@protocol HIDDeviceProtocol <NSObject>
- (id)initWithIOHIDDeviceRef: (IOHIDDeviceRef)device;
- (BOOL)open;
- (BOOL)close;
- (IOHIDDeviceRef)deviceRef;
- (NSNumber *)getNumberProperty: (NSString *)key;
- (NSNumber *)getLocationID;
- (BOOL)setReport: (int)reportID output:(NSData *)data;
@end


@interface HIDDevice : NSObject <HIDDeviceProtocol> {
@private
  IOHIDDeviceRef deviceRef_;
}
@end

@interface WebmailNotifier : NSObject {
@private
  NSArray *devices_;
}

- (id)initWithHIDManager: (HIDManager *)manager;
- (NSUInteger)count;
- (NSArray *)devices;
- (void)outputDevices;
- (BOOL)setDevice: (int)deviceIndex color:(int)colorIndex;
@end


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


@implementation WebmailNotifier

- (id)initWithHIDManager: (HIDManager *)manager {
  self = [super init];
  if (self == nil) {
    return nil;
  }

  const int kProductID = 0x1320;
  const int kVendorID = 0x1294;
  devices_ = [manager getDevicesWithVendorID:kVendorID productID:kProductID];
  return self;
}

- (NSArray *)devices {
  return devices_;
}

- (NSUInteger) count {
  return [devices_ count];
}

- (void)outputDevices {
  int index = 0;
  for (id<HIDDeviceProtocol> device in devices_) {
    NSLog(@"%d: 0x%x", index, [[device getLocationID] intValue]);
    ++index;
  }
}

- (BOOL)setDevice: (int)deviceIndex color:(int)colorIndex {
  if (colorIndex > 7) {
    NSLog(@"ERROR: invalid color argument.");
    return NO;
  }
  
  id<HIDDeviceProtocol> device = [devices_ objectAtIndex:deviceIndex];
  if (![device open]) {
    NSLog(@"ERROR: failed IOHIDDeviceOpen.");
    return NO;
  }
  
  const size_t kBufferSize = 1;
  uint8_t buffer[kBufferSize];
  buffer[0] = colorIndex;
  NSData *data = [[NSData alloc] initWithBytes:buffer length:kBufferSize];
  const CFIndex kReportID = 0;
  if (![device setReport:kReportID output:data]) {
    NSLog(@"ERROR: failed IOHIDDeviceSetReport.");
    return NO;
  }
  
  if (![device close]) {
    NSLog(@"ERROR: failed IOHIDDeviceClose.");
    return NO;
  }
  
  return YES;
}
@end

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    int index = 0;
    int color = 0;
    if (argc > 2) {
      index = atoi(argv[2]);
    }
    if (argc > 1) {
      color = atoi(argv[1]);
    }

    HIDManager *manager = [[HIDManager alloc] init];
    WebmailNotifier *notifier = [[WebmailNotifier alloc] initWithHIDManager:manager];
    const NSUInteger count = [notifier count];
    [notifier outputDevices];

    if (count == 0) {
      NSLog(@"No devices are found.");
      return 1;
    } else if (count <= index) {
      NSLog(@"Invalid device index");
      return 1;
    }
    
    [notifier setDevice:index color:color];
    return 0;
  }
}



