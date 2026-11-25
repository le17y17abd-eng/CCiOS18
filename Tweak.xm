#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// Stage 1: visual-only treatment. Native Control Center controls remain untouched.
static const NSInteger kCCiOS18BackdropTag = 180018;
static const void *kCCiOS18StyledKey = &kCCiOS18StyledKey;

static void CCiOS18AddBackdrop(UIView *root) {
    if (!root || [root viewWithTag:kCCiOS18BackdropTag]) return;

    UIVisualEffectView *backdrop =
      [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    backdrop.tag = kCCiOS18BackdropTag;
    backdrop.userInteractionEnabled = NO;
    backdrop.frame = root.bounds;
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [root insertSubview:backdrop atIndex:0];

    UIView *shade = [[UIView alloc] initWithFrame:backdrop.bounds];
    shade.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.10];
    shade.userInteractionEnabled = NO;
    shade.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [backdrop.contentView addSubview:shade];
}

static void CCiOS18RoundModuleViews(UIView *view) {
    if (!view) return;

    NSString *name = NSStringFromClass(view.class);
    BOOL candidate = ([name containsString:@"Module"] || [name containsString:@"module"]) &&
                    ![name containsString:@"Controller"];

    if (candidate && ![objc_getAssociatedObject(view, kCCiOS18StyledKey) boolValue]) {
        objc_setAssociatedObject(view, kCCiOS18StyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.layer.cornerRadius = 16.0;
        view.layer.cornerCurve = kCACornerCurveContinuous;
        view.layer.borderWidth = 0.5;
        view.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;
        view.layer.masksToBounds = YES;
    }

    for (UIView *child in view.subviews) CCiOS18RoundModuleViews(child);
}

%hook CCUIModularControlCenterOverlayViewController
- (void)viewDidLayoutSubviews {
    %orig;
    // Logos forward-declares hooked classes; cast to UIViewController to access its view.
    UIView *rootView = [(UIViewController *)self view];
    CCiOS18AddBackdrop(rootView);
    CCiOS18RoundModuleViews(rootView);
}
%end
