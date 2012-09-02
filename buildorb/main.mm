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
  IOHIDManagerRef manager_ref_;  
}

- (id)init;
- (void)dealloc;
- (IOHIDManagerRef)managerRef;
- (NSArray *) getDevicesWithVendorId: (int)vendor_id productId: (int)product_id;
@end


@interface HIDDevice : NSObject {
@private
  IOHIDDeviceRef device_ref_;
}

- (id)initWithIOHIDDeviceRef: (IOHIDDeviceRef)device;
- (BOOL)open;
- (BOOL)close;
- (IOHIDDeviceRef)deviceRef;
- (NSNumber *)getNumberProperty: (NSString *)key;
- (NSNumber *)getLocationId;
@end

@interface WebmailNotifier : NSObject {
@private
  NSArray *devices_;
}

- (id)initWithHIDManager: (HIDManager *)manager;
- (NSUInteger) count;
- (NSArray *)devices;
- (void)outputDevices;
@end


namespace {
NSInteger CompareDeviceRef(id device1, id device2, void *context) {
  const int comp = ([[(HIDDevice *)device1 getLocationId] intValue] -
                    [[(HIDDevice *)device2 getLocationId] intValue]); 
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
    manager_ref_ = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    IOHIDManagerScheduleWithRunLoop(manager_ref_,
                                    CFRunLoopGetMain(),
                                    kCFRunLoopDefaultMode);
    const IOReturn result = IOHIDManagerOpen(manager_ref_, kIOHIDOptionsTypeNone);
    if (result != kIOReturnSuccess) {
      NSLog(@"Failed IOHIDManagerOpen.");
    }
  }
  return self;
}

- (void)dealloc {
  CFRelease(manager_ref_);
}

- (IOHIDManagerRef)managerRef {
  return manager_ref_;
}

- (NSArray *)getDevicesWithVendorId:(int)vendor_id productId:(int)product_id {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dict setObject:[NSNumber numberWithInt:vendor_id]
           forKey:[NSString stringWithCString:kIOHIDVendorIDKey
                                     encoding:NSUTF8StringEncoding]];
  [dict setObject:[NSNumber numberWithInt:product_id]
           forKey:[NSString stringWithCString:kIOHIDProductIDKey
                                     encoding:NSUTF8StringEncoding]];

  IOHIDManagerSetDeviceMatching(manager_ref_, (CFDictionaryRef)dict);

  NSSet *device_set = (NSSet *)IOHIDManagerCopyDevices(manager_ref_);

  NSEnumerator *set_enum = [device_set objectEnumerator];
  NSMutableArray *device_array = [[NSMutableArray alloc] init];
  IOHIDDeviceRef device_ref;
  while ((device_ref = (IOHIDDeviceRef)[set_enum nextObject]) != nil) {
    [device_array addObject:[[HIDDevice alloc]
                             initWithIOHIDDeviceRef:device_ref]];
  }
  NSArray *sorted_array = [device_array
                           sortedArrayUsingFunction:CompareDeviceRef
                           context:NULL];
  return sorted_array;
}
@end

@implementation HIDDevice
- (id)initWithIOHIDDeviceRef: (IOHIDDeviceRef)device {
  self = [super init];
  if (self != nil) {
    device_ref_ = device;
  }
  return self;
}

- (IOHIDDeviceRef)deviceRef {
  return device_ref_;
}

- (BOOL)open {
  const IOReturn result = IOHIDDeviceOpen(device_ref_, kIOHIDOptionsTypeNone);
  return (result == kIOReturnSuccess);
}

- (BOOL)close {
  const IOReturn result = IOHIDDeviceClose(device_ref_, kIOHIDOptionsTypeNone);
  return (result == kIOReturnSuccess);
}

- (NSNumber *)getNumberProperty:(NSString *)key {
  if (!IOHIDDeviceGetTypeID() == CFGetTypeID(device_ref_)) {
    return nil;
  }
  
  CFTypeRef cftype_ref = IOHIDDeviceGetProperty(device_ref_, (CFStringRef)key);
  if (!cftype_ref ||
      CFNumberGetTypeID() != CFGetTypeID(cftype_ref)) {
    return nil;
  }
  
  return (NSNumber *)cftype_ref;
}

- (NSNumber *)getLocationId {
  return [self getNumberProperty:
          [NSString stringWithCString:kIOHIDLocationIDKey
                             encoding:NSUTF8StringEncoding]];
}
@end


@implementation WebmailNotifier

- (id)initWithHIDManager: (HIDManager *)manager {
  self = [super init];
  if (self == nil) {
    return nil;
  }

  const int kProductId = 0x1320;
  const int kVendorId = 0x1294;
  devices_ = [manager getDevicesWithVendorId:kVendorId productId:kProductId];
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
  for (HIDDevice *device in devices_) {
    printf("%d: 0x%x\n", index, [[device getLocationId] intValue]);
    ++index;
  }
}
@end

namespace {
bool GetDevice(const int index,
               IOHIDDeviceRef *device) {
  HIDManager *manager = [[HIDManager alloc] init];
  WebmailNotifier *notifier = [[WebmailNotifier alloc] initWithHIDManager:manager];
  NSArray *device_array = [notifier devices];
  const NSUInteger count = [device_array count];
  if (count == 0 || count <= index) {
    return false;
  }
    
  [notifier outputDevices];
  *device = [[device_array objectAtIndex:index] deviceRef];
  return true;
}
  

bool SetColor(HIDDevice *device, const int color) {
  if (color > 7) {
    NSLog(@"ERROR: invalid argument.");
    return false;
  }
  
  if (![device open]) {
    NSLog(@"ERROR: failed IOHIDDeviceOpen.");
    return false;
  }
  
  const size_t kBufferSize = 1;
  uint8_t buffer[kBufferSize];
  buffer[0] = color;
  const CFIndex kReportID = 0;
  const IOReturn result = IOHIDDeviceSetReport(
      [device deviceRef], kIOHIDReportTypeOutput, kReportID, buffer, kBufferSize);
  if (result != kIOReturnSuccess) {
    NSLog(@"ERROR: failed IOHIDDeviceSetReport.");
    return false;
  }
  
  if (![device close]) {
    NSLog(@"ERROR: failed IOHIDDeviceClose.");
    return false;
  }
  
  return true;
}
}  // namespace

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
      printf("No devices are found.\n");
      return 1;
    } else if (count <= index) {
      printf("Invalid device index\n");
      return 1;
    }
    
    HIDDevice *device = [[notifier devices] objectAtIndex:index];
    SetColor(device, color);
  
    return 0;
  }
}



