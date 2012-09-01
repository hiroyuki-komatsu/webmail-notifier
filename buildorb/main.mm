//
//  main.m
//  buildorb
//
//  Created by Hiroyuki Komatsu on 9/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <IOKit/hid/IOHIDLib.h>
#include <stdio.h>
#include <stdlib.h>

namespace {
bool CreateAndInitHidManager(IOHIDManagerRef *hid_manager) {
  *hid_manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
  IOHIDManagerScheduleWithRunLoop(*hid_manager,
                                  CFRunLoopGetMain(),
                                  kCFRunLoopDefaultMode);
  const IOReturn result = IOHIDManagerOpen(*hid_manager, kIOHIDOptionsTypeNone);
  return (result == kIOReturnSuccess);
}

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

int CompareDeviceRef(const void *device_a, const void *device_b) {
  return ((int)GetLocationID(*(IOHIDDeviceRef*)device_a) -
          (int)GetLocationID(*(IOHIDDeviceRef*)device_b));
}

bool GetDevice(IOHIDManagerRef hid_manager,
               const int index,
               IOHIDDeviceRef *device) {
  const int kProductId = 0x1320;
  const int kVendorId = 0x1294;
  
  CFMutableDictionaryRef dict = CFDictionaryCreateMutable(
                                                          kCFAllocatorDefault, 0,
                                                          &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionarySetValue(dict, CFSTR(kIOHIDProductIDKey),
                       CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType,
                                      &kProductId));
  CFDictionarySetValue(dict, CFSTR(kIOHIDVendorIDKey),
                       CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType,
                                      &kVendorId));
  IOHIDManagerSetDeviceMatching(hid_manager, dict);
  CFRelease(dict);
  
  CFSetRef device_set = IOHIDManagerCopyDevices(hid_manager);
  const CFIndex count = CFSetGetCount(device_set);
  if (count == 0 || count <= index) {
    CFRelease(device_set);
    return false;
  }
  
  IOHIDDeviceRef *device_array = (IOHIDDeviceRef *)malloc(count * sizeof(IOHIDDeviceRef));
  CFSetGetValues(device_set, (const void **)device_array);
  CFRelease(device_set);
  
  printf("%d\n", (int)count);
  qsort(device_array, count, sizeof(IOHIDDeviceRef), CompareDeviceRef);
  
  for (int i = 0; i < (int)count; ++i) { 
    printf("%d: 0x%lx\n", i, GetLocationID(device_array[i]));
  }
  
  *device = device_array[index];
  free(device_array);
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
    if (argc < 2 || 3 < argc) {
      return 1;
    }
  
    IOHIDManagerRef hid_manager = NULL;
    if (!CreateAndInitHidManager(&hid_manager)) {
      NSLog(@"ERROR: failed CreateAndInitHidManager.");
      return false;
    }
  
    IOHIDDeviceRef device_ref = NULL;
    const int index = (argc == 2) ? 0 : atoi(argv[2]);
    if (!GetDevice(hid_manager, index, &device_ref)) {
      NSLog(@"ERROR: failed GetDevice.");
      return false;
    }
  
    const int color = atoi(argv[1]);
    SetColor(device_ref, color);
  
    return 0;
  }
}



