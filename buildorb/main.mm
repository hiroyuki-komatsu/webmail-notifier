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
- (NSSet *) copyDeviceSetWithVendorId: (int)vendor_id productId: (int)product_id;
@end


@interface HIDDevice : NSObject {
@private
  IOHIDDeviceRef device_ref_;
}  
@end


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

- (NSSet *)copyDeviceSetWithVendorId:(int)vendor_id productId:(int)product_id {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dict setObject:[NSNumber numberWithInt:vendor_id]
           forKey:[NSString stringWithCString:kIOHIDVendorIDKey
                                     encoding:NSUTF8StringEncoding]];
  [dict setObject:[NSNumber numberWithInt:product_id]
           forKey:[NSString stringWithCString:kIOHIDProductIDKey
                                     encoding:NSUTF8StringEncoding]];

  IOHIDManagerSetDeviceMatching(manager_ref_, (CFDictionaryRef)dict);
  return (NSSet *)IOHIDManagerCopyDevices(manager_ref_);
}

@end



namespace {
bool GetLongProperty(IOHIDDeviceRef device_ref,
                     CFStringRef key,
                     long *value) {
  if (!device_ref ||
      !IOHIDDeviceGetTypeID() == CFGetTypeID(device_ref)) {
    return false;
  }
  
  CFTypeRef cftype_ref = IOHIDDeviceGetProperty(device_ref, key);
  if (!cftype_ref ||
      CFNumberGetTypeID() != CFGetTypeID(cftype_ref)) {
    return false;
  }
  
  return CFNumberGetValue((CFNumberRef)cftype_ref,
                          kCFNumberSInt32Type,
                          value);
}

long GetLocationID(IOHIDDeviceRef device_ref) {
  long result = 0;
  GetLongProperty(device_ref,
                  CFSTR(kIOHIDLocationIDKey),
                  &result);
  return result;
}

NSInteger CompareDeviceRef(id device1, id device2, void *context) {
  const int comp = ((int)GetLocationID((IOHIDDeviceRef)device1) -
                    (int)GetLocationID((IOHIDDeviceRef)device2)); 
  if (comp < 0) {
    return NSOrderedAscending;
  } else if (comp > 0) {
    return NSOrderedDescending;
  } else {
    return NSOrderedSame;
  }
}
  
bool GetDevice(const int index,
               IOHIDDeviceRef *device) {
  HIDManager *manager_obj = [[HIDManager alloc] init];
  
  const int kProductId = 0x1320;
  const int kVendorId = 0x1294;
  NSSet *device_set = [manager_obj copyDeviceSetWithVendorId:kVendorId productId:kProductId];
  const NSUInteger count = [device_set count];
  if (count == 0 || count <= index) {
    return false;
  }
  
  NSArray *device_array = [[device_set allObjects] sortedArrayUsingFunction:CompareDeviceRef
                                                                    context:NULL];
  printf("%d\n", (int)count);
    
  for (int i = 0; i < (int)count; ++i) { 
    printf("%d: 0x%lx\n", i, GetLocationID((IOHIDDeviceRef)[device_array objectAtIndex:i]));
  }
    
  *device = (IOHIDDeviceRef)[device_array objectAtIndex:index];
  return true;
}
  

bool SetColor(IOHIDDeviceRef device_ref, const int color) {
  if (color > 7) {
    NSLog(@"ERROR: invalid argument.");
    return false;
  }
  
  if (IOHIDDeviceOpen(device_ref, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
    NSLog(@"ERROR: failed IOHIDDeviceOpen.");
    return false;
  }
  
  const size_t kBufferSize = 1;
  uint8_t buffer[kBufferSize];
  buffer[0] = color;
  const CFIndex kReportID = 0;
  const IOReturn result = IOHIDDeviceSetReport(
                                               device_ref, kIOHIDReportTypeOutput, kReportID, buffer, kBufferSize);
  if (result != kIOReturnSuccess) {
    NSLog(@"ERROR: failed IOHIDDeviceSetReport.");
    return false;
  }
  
  if (IOHIDDeviceClose(device_ref, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
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

    IOHIDDeviceRef device_ref = NULL;
//    const int index = (argc == 2) ? 0 : atoi(argv[2]);
    if (!GetDevice(index, &device_ref)) {
      NSLog(@"ERROR: failed GetDevice.");
      return false;
    }
  
//    const int color = atoi(argv[1]);
    SetColor(device_ref, color);
  
    return 0;
  }
}



