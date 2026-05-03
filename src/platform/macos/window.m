#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAMetalLayer.h>

typedef struct PlatformWindow {
  NSWindow *ns_window;
  NSView *content_view;
  CAMetalLayer *metal_layer;
  bool should_close;
} PlatformWindow;

@interface MetalView : NSView
@property(nonatomic, assign) PlatformWindow *owner;
@end

@implementation MetalView
+ (Class)layerClass {
  return [CAMetalLayer class];
}

- (CALayer *)makeBackingLayer {
  return [CAMetalLayer layer];
}

- (BOOL)wantsUpdateLayer {
  return YES;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.wantsLayer = YES;
    self.layer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
  }
  return self;
}

- (void)viewDidChangeBackingProperties {
  [super viewDidChangeBackingProperties];
  if (self.window) {
    self.layer.contentsScale = self.window.backingScaleFactor;
    CAMetalLayer *layer = (CAMetalLayer *)self.layer;
    CGSize size = self.bounds.size;
    layer.drawableSize =
        CGSizeMake(size.width * self.window.backingScaleFactor,
                   size.height * self.window.backingScaleFactor);
  }
}

- (void)setFrameSize:(NSSize)newSize {
  [super setFrameSize:newSize];
  CAMetalLayer *layer = (CAMetalLayer *)self.layer;
  CGFloat scale = self.window ? self.window.backingScaleFactor : 1.0;
  layer.drawableSize =
      CGSizeMake(newSize.width * scale, newSize.height * scale);
}

@end

@interface WindowDelegate : NSObject <NSWindowDelegate>
@property(nonatomic, assign) PlatformWindow *owner;
@end

@implementation WindowDelegate
- (BOOL)windowShouldClose:(NSWindow *)sender {
  self.owner->should_close = true;
  return NO;
}
@end

typedef struct PlatformWindow PlatformWindow;

static NSMutableArray<NSValue *> *g_open_windows = nil;

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (void)requestQuit:(id)sender {
  for (NSValue *boxed in g_open_windows) {
    PlatformWindow *w = (PlatformWindow *)[boxed pointerValue];
    w->should_close = true;
  }
}

@end

void install_menu_bar(NSString *app_name, AppDelegate *app_delegate) {
  NSMenu *main_menu = [[NSMenu alloc] init];
  NSMenuItem *app_menu_item = [[NSMenuItem alloc] init];
  [main_menu addItem:app_menu_item];

  NSMenu *app_menu = [[NSMenu alloc] init];

  NSString *about_title = [@"About " stringByAppendingString:app_name];
  [app_menu addItemWithTitle:about_title
                      action:@selector(orderFrontStandardAboutPanel:)
               keyEquivalent:@""];

  [app_menu addItem:[NSMenuItem separatorItem]];

  NSString *hide_title = [@"Hide " stringByAppendingString:app_name];
  [app_menu addItemWithTitle:hide_title
                      action:@selector(hide:)
               keyEquivalent:@"h"];

  NSMenuItem *hide_others =
      [app_menu addItemWithTitle:@"Hide Others"
                          action:@selector(hideOtherApplications:)
                   keyEquivalent:@"h"];
  [hide_others setKeyEquivalentModifierMask:(NSEventModifierFlagOption |
                                             NSEventModifierFlagCommand)];

  [app_menu addItemWithTitle:@"Show All"
                      action:@selector(unhideAllApplications:)
               keyEquivalent:@""];

  [app_menu addItem:[NSMenuItem separatorItem]];

  NSString *quit_title = [@"Quit " stringByAppendingString:app_name];
  NSMenuItem *quit_item = [app_menu addItemWithTitle:quit_title
                                              action:@selector(requestQuit:)
                                       keyEquivalent:@"q"];
  [quit_item setTarget:app_delegate];

  [app_menu_item setSubmenu:app_menu];
  [NSApp setMainMenu:main_menu];
}

void platform_init(void) {
  [NSApplication sharedApplication];
  [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

  g_open_windows = [[NSMutableArray alloc] init];
  AppDelegate *app_delegate = [[AppDelegate alloc] init];
  [NSApp setDelegate:app_delegate];
  NSString *app_name = [[NSProcessInfo processInfo] processName];
  install_menu_bar(app_name, app_delegate);

  [NSApp finishLaunching];
}

PlatformWindow *platform_window_create(int width, int height,
                                       const char *title) {
  PlatformWindow *w = calloc(1, sizeof(PlatformWindow));
  [g_open_windows addObject:[NSValue valueWithPointer:w]];

  NSRect frame = NSMakeRect(0, 0, width, height);
  NSWindowStyleMask style =
      NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
      NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable;

  w->ns_window = [[NSWindow alloc] initWithContentRect:frame
                                             styleMask:style
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];

  MetalView *view = [[MetalView alloc] initWithFrame:frame];
  view.owner = w;
  w->content_view = view;
  w->metal_layer = (CAMetalLayer *)view.layer;
  w->metal_layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
  w->metal_layer.framebufferOnly = NO;

  [w->ns_window setContentView:view];

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
  NSValue *boxed = [NSValue valueWithPointer:w];
  NSUInteger index = [g_open_windows
      indexOfObjectPassingTest:^BOOL(NSValue *obj, NSUInteger idx, BOOL *stop) {
        return [obj pointerValue] == w;
      }];
  if (index != NSNotFound) {
    [g_open_windows removeObjectAtIndex:index];
  }
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