#import <Cocoa/Cocoa.h>

typedef struct PlatformWindow {
  NSWindow *ns_window;
  bool should_close;
} PlatformWindow;

@interface WindowDelegate : NSObject <NSWindowDelegate>
@property(nonatomic, assign) PlatformWindow *owner;
@end

@implementation WindowDelegate
- (BOOL)windowShouldClose:(NSWindow *)sender {
  self.owner->should_close = true;
  return NO;
}
@end

void platform_init(void) {
  [NSApplication sharedApplication];
  [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
  [NSApp finishLaunching];
}

PlatformWindow *platform_window_create(int width, int height,
                                       const char *title) {
  PlatformWindow *w = calloc(1, sizeof(PlatformWindow));

  NSRect frame = NSMakeRect(0, 0, width, height);
  NSWindowStyleMask style =
      NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
      NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable;

  w->ns_window = [[NSWindow alloc] initWithContentRect:frame
                                             styleMask:style
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];

  WindowDelegate *delegate = [[WindowDelegate alloc] init];
  delegate.owner = w;
  [w->ns_window setDelegate:delegate];
  [w->ns_window setTitle:[NSString stringWithUTF8String:title]];
  [w->ns_window center];
  [w->ns_window makeKeyAndOrderFront:nil];

  [NSApp activateIgnoringOtherApps:YES];
  return w;
}

void platform_window_destroy(PlatformWindow *w) {
  [w->ns_window close];
  free(w);
}

bool platform_window_should_close(PlatformWindow *w) { return w->should_close; }

void platform_pump_events(void) {
  @autoreleasepool {
    NSEvent *event;
    while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                       untilDate:[NSDate distantPast]
                                          inMode:NSDefaultRunLoopMode
                                         dequeue:YES])) {
      [NSApp sendEvent:event];
    }
  }
}