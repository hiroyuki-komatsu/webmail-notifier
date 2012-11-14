//
//  main.m
//  buildorb
//
//  Created by Hiroyuki Komatsu on 9/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>

#import "HIDManager.h"

#include <stdio.h>
#include <stdlib.h>


@interface WebmailNotifier : NSObject {
@private
  NSArray *devices_;
}

- (id)initWithHIDManager: (id<HIDManagerProtocol>)manager;
- (NSUInteger)count;
- (NSArray *)devices;
- (void)outputDevices;
- (BOOL)setDevice: (int)deviceIndex color:(int)colorIndex;
@end




@implementation WebmailNotifier

- (id)initWithHIDManager: (id<HIDManagerProtocol>)manager {
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



