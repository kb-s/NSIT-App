/*
 Copyright (c) 2013 Joan Lluch <joan.lluch@sweetwilliamsl.com>
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is furnished
 to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.

 Early code inspired on a similar class by Philip Kluz (Philip.Kluz@zuui.org)
*/

#import <QuartzCore/QuartzCore.h>

#import "SWRevealViewController.h"

static CGFloat statusBarAdjustment( UIView* view ){
    CGFloat adjustment = 0.0f;
    UIApplication *app = [UIApplication sharedApplication];
    CGRect viewFrame = [view convertRect:view.bounds toView:[app keyWindow]];
    CGRect statusBarFrame = [app statusBarFrame];
    
    if ( CGRectIntersectsRect(viewFrame, statusBarFrame) )
        adjustment = fminf(statusBarFrame.size.width, statusBarFrame.size.height);

    return adjustment;
}

@interface SWRevealView: UIView{
    __weak SWRevealViewController *_c;
}

@property (nonatomic, readonly) UIView *rearView;
@property (nonatomic, readonly) UIView *rightView;
@property (nonatomic, readonly) UIView *frontView;
@property (nonatomic, assign) BOOL disableLayout;

@end


@interface SWRevealViewController()
- (void)_getRevealWidth:(CGFloat*)pRevealWidth revealOverDraw:(CGFloat*)pRevealOverdraw forSymetry:(int)symetry;
- (void)_getBounceBack:(BOOL*)pBounceBack pStableDrag:(BOOL*)pStableDrag forSymetry:(int)symetry;
- (void)_getAdjustedFrontViewPosition:(FrontViewPosition*)frontViewPosition forSymetry:(int)symetry;
@end


@implementation SWRevealView

static CGFloat scaledValue( CGFloat v1, CGFloat min2, CGFloat max2, CGFloat min1, CGFloat max1)
{
    CGFloat result = min2 + (v1-min1)*((max2-min2)/(max1-min1));
    if ( result != result ) return min2;  // nan
    if ( result < min2 ) return min2;
    if ( result > max2 ) return max2;
    return result;
}
- (id)initWithFrame:(CGRect)frame controller:(SWRevealViewController*)controller{
    self = [super initWithFrame:frame];
    if ( self ){
        _c = controller;
        CGRect bounds = self.bounds;
        _frontView = [[UIView alloc] initWithFrame:bounds];
        _frontView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self reloadShadow];
        [self addSubview:_frontView];
    }
    return self;
}
- (void)reloadShadow
{
    CALayer *frontViewLayer = _frontView.layer;
    frontViewLayer.shadowColor = [_c.frontViewShadowColor CGColor];
    frontViewLayer.shadowOpacity = _c.frontViewShadowOpacity;
    frontViewLayer.shadowOffset = _c.frontViewShadowOffset;
    frontViewLayer.shadowRadius = _c.frontViewShadowRadius;
}
- (CGRect)hierarchycalFrameAdjustment:(CGRect)frame{
    if ( _c.presentFrontViewHierarchically ){
        UINavigationBar *dummyBar = [[UINavigationBar alloc] init];
        CGFloat barHeight = [dummyBar sizeThatFits:CGSizeMake(100,100)].height;
        CGFloat offset = barHeight + statusBarAdjustment(self);
        frame.origin.y += offset;
        frame.size.height -= offset;
    }
    return frame;
}
- (void)prepareRearViewForPosition:(FrontViewPosition)newPosition{
    if ( _rearView == nil ){
        _rearView = [[UIView alloc] initWithFrame:self.bounds];
        _rearView.autoresizingMask = /*UIViewAutoresizingFlexibleWidth|*/UIViewAutoresizingFlexibleHeight;
        [self insertSubview:_rearView belowSubview:_frontView];
    }
    
    CGFloat xLocation = [self frontLocationForPosition:_c.frontViewPosition];
    [self _layoutRearViewsForLocation:xLocation];
    [self _prepareForNewPosition:newPosition];
}
- (void)prepareRightViewForPosition:(FrontViewPosition)newPosition{
    if ( _rightView == nil ){
        _rightView = [[UIView alloc] initWithFrame:self.bounds];
        _rightView.autoresizingMask = /*UIViewAutoresizingFlexibleWidth|*/UIViewAutoresizingFlexibleHeight;
        [self insertSubview:_rightView belowSubview:_frontView];
    }
    CGFloat xLocation = [self frontLocationForPosition:_c.frontViewPosition];
    [self _layoutRearViewsForLocation:xLocation];
    [self _prepareForNewPosition:newPosition];
}
- (void)unloadRearView{
    [_rearView removeFromSuperview];
    _rearView = nil;
}
- (void)unloadRightView{
    [_rightView removeFromSuperview];
    _rightView = nil;
}
- (CGFloat)frontLocationForPosition:(FrontViewPosition)frontViewPosition
{
    CGFloat revealWidth;
    CGFloat revealOverdraw;
    CGFloat location = 0.0f;
    int symetry = frontViewPosition<FrontViewPositionLeft? -1 : 1;
    [_c _getRevealWidth:&revealWidth revealOverDraw:&revealOverdraw forSymetry:symetry];
    [_c _getAdjustedFrontViewPosition:&frontViewPosition forSymetry:symetry];
    if ( frontViewPosition == FrontViewPositionRight )
        location = revealWidth;
    else if ( frontViewPosition > FrontViewPositionRight )
        location = revealWidth + revealOverdraw;
    return location*symetry;
}


- (void)dragFrontViewToXLocation:(CGFloat)xLocation
{
    CGRect bounds = self.bounds;
    xLocation = [self _adjustedDragLocationForLocation:xLocation];
    [self _layoutRearViewsForLocation:xLocation];
    CGRect frame = CGRectMake(xLocation, 0.0f, bounds.size.width, bounds.size.height);
    _frontView.frame = [self hierarchycalFrameAdjustment:frame];
}

- (void)layoutSubviews
{
    if ( _disableLayout ) return;
    CGRect bounds = self.bounds;
    FrontViewPosition position = _c.frontViewPosition;
    CGFloat xLocation = [self frontLocationForPosition:position];
    [self _layoutRearViewsForLocation:xLocation];
    CGRect frame = CGRectMake(xLocation, 0.0f, bounds.size.width, bounds.size.height);
    _frontView.frame = [self hierarchycalFrameAdjustment:frame];
    UIViewController *frontViewController = _c.frontViewController;
    BOOL viewLoaded = frontViewController != nil && frontViewController.isViewLoaded;
    BOOL viewNotRemoved = position > FrontViewPositionLeftSideMostRemoved && position < FrontViewPositionRightMostRemoved;
    CGRect shadowBounds = viewLoaded && viewNotRemoved  ? _frontView.bounds : CGRectZero;
    
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:shadowBounds];
    _frontView.layer.shadowPath = shadowPath.CGPath;
}
- (BOOL)pointInsideD:(CGPoint)point withEvent:(UIEvent *)event
{
    BOOL isInside = [super pointInside:point withEvent:event];
    if ( _c.extendsPointInsideHit ){
        if ( !isInside  && _rearView && [_c.rearViewController isViewLoaded] ){
            CGPoint pt = [self convertPoint:point toView:_rearView];
            isInside = [_rearView pointInside:pt withEvent:event];
        }
        if ( !isInside && _frontView && [_c.frontViewController isViewLoaded] ){
            CGPoint pt = [self convertPoint:point toView:_frontView];
            isInside = [_frontView pointInside:pt withEvent:event];
        }
        
        if ( !isInside && _rightView && [_c.rightViewController isViewLoaded] ){
            CGPoint pt = [self convertPoint:point toView:_rightView];
            isInside = [_rightView pointInside:pt withEvent:event];
        }
    }
    return isInside;
}
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event{
    BOOL isInside = [super pointInside:point withEvent:event];
    if ( !isInside && _c.extendsPointInsideHit ){
        UIView *testViews[] = { _rearView, _frontView, _rightView };
        UIViewController *testControllers[] = { _c.rearViewController, _c.frontViewController, _c.rightViewController };
        for ( NSInteger i=0 ; i<3 && !isInside ; i++ ){
            if ( testViews[i] && [testControllers[i] isViewLoaded] ){
                CGPoint pt = [self convertPoint:point toView:testViews[i]];
                isInside = [testViews[i] pointInside:pt withEvent:event];
            }
        }
    }
    return isInside;
}

- (void)_layoutRearViewsForLocation:(CGFloat)xLocation
{
    CGRect bounds = self.bounds;
    CGFloat rearRevealWidth = _c.rearViewRevealWidth;
    if ( rearRevealWidth < 0) rearRevealWidth = bounds.size.width + _c.rearViewRevealWidth;
    CGFloat rearXLocation = scaledValue(xLocation, -_c.rearViewRevealDisplacement, 0, 0, rearRevealWidth);
    CGFloat rearWidth = rearRevealWidth + _c.rearViewRevealOverdraw;
    _rearView.frame = CGRectMake(rearXLocation, 0.0, rearWidth, bounds.size.height);
    CGFloat rightRevealWidth = _c.rightViewRevealWidth;
    if ( rightRevealWidth < 0) rightRevealWidth = bounds.size.width + _c.rightViewRevealWidth;
    CGFloat rightXLocation = scaledValue(xLocation, 0, _c.rightViewRevealDisplacement, -rightRevealWidth, 0);
    CGFloat rightWidth = rightRevealWidth + _c.rightViewRevealOverdraw;
    _rightView.frame = CGRectMake(bounds.size.width-rightWidth+rightXLocation, 0.0f, rightWidth, bounds.size.height);
}


- (void)_prepareForNewPosition:(FrontViewPosition)newPosition;{
    if ( _rearView == nil || _rightView == nil )
        return;
    int symetry = newPosition<FrontViewPositionLeft? -1 : 1;
    NSArray *subViews = self.subviews;
    NSInteger rearIndex = [subViews indexOfObjectIdenticalTo:_rearView];
    NSInteger rightIndex = [subViews indexOfObjectIdenticalTo:_rightView];
    if ( (symetry < 0 && rightIndex < rearIndex) || (symetry > 0 && rearIndex < rightIndex) )
        [self exchangeSubviewAtIndex:rightIndex withSubviewAtIndex:rearIndex];
}

- (CGFloat)_adjustedDragLocationForLocation:(CGFloat)x
{
    CGFloat result;
    CGFloat revealWidth;
    CGFloat revealOverdraw;
    BOOL bounceBack;
    BOOL stableDrag;
    FrontViewPosition position = _c.frontViewPosition;
    int symetry = x<0 ? -1 : 1;
    [_c _getRevealWidth:&revealWidth revealOverDraw:&revealOverdraw forSymetry:symetry];
    [_c _getBounceBack:&bounceBack pStableDrag:&stableDrag forSymetry:symetry];
    BOOL stableTrack = !bounceBack || stableDrag || position==FrontViewPositionRightMost || position==FrontViewPositionLeftSideMost;
    if ( stableTrack ){
        revealWidth += revealOverdraw;
        revealOverdraw = 0.0f;
    }
    x = x * symetry;
    if (x <= revealWidth)
        result = x;         // Translate linearly.
    else if (x <= revealWidth+2*revealOverdraw)
        result = revealWidth + (x-revealWidth)/2;   // slow down translation by halph the movement.
    else
        result = revealWidth+revealOverdraw;        // keep at the rightMost location.
    return result * symetry;
}
@end

@interface SWContextTransitionObject : NSObject<UIViewControllerContextTransitioning>
@end

@implementation SWContextTransitionObject{
    __weak SWRevealViewController *_revealVC;
    UIView *_view;
    UIViewController *_toVC;
    UIViewController *_fromVC;
    void (^_completion)(void);
}
- (id)initWithRevealController:(SWRevealViewController*)revealVC containerView:(UIView*)view fromVC:(UIViewController*)fromVC
    toVC:(UIViewController*)toVC completion:(void (^)(void))completion
{
    self = [super init];
    if ( self ){
        _revealVC = revealVC;
        _view = view;
        _fromVC = fromVC;
        _toVC = toVC;
        _completion = completion;
    }
    return self;
}
- (UIView *)containerView{
    return _view;
}
- (BOOL)isAnimated{
    return YES;
}
- (BOOL)isInteractive{
    return NO;  // not supported
}
- (BOOL)transitionWasCancelled{
    return NO; // not supported
}
- (CGAffineTransform)targetTransform{
    return CGAffineTransformIdentity;
}
- (UIModalPresentationStyle)presentationStyle
{
    return UIModalPresentationNone;  // not applicable
}
- (void)updateInteractiveTransition:(CGFloat)percentComplete
{}
- (void)finishInteractiveTransition
{}

- (void)cancelInteractiveTransition
{}
- (void)completeTransition:(BOOL)didComplete
{
    _completion();
}
- (UIViewController *)viewControllerForKey:(NSString *)key
{
    if ( [key isEqualToString:UITransitionContextFromViewControllerKey] )
        return _fromVC;
    
    if ( [key isEqualToString:UITransitionContextToViewControllerKey] )
        return _toVC;
    
    return nil;
}
- (UIView *)viewForKey:(NSString *)key
{
    return nil;
}
- (CGRect)initialFrameForViewController:(UIViewController *)vc
{
    return _view.bounds;
}
- (CGRect)finalFrameForViewController:(UIViewController *)vc
{
    return _view.bounds;
}
@end

@interface SWDefaultAnimationController : NSObject<UIViewControllerAnimatedTransitioning>
@end

@implementation SWDefaultAnimationController
{
    NSTimeInterval _duration;
}
- (id)initWithDuration:(NSTimeInterval)duration{
    self = [super init];
    if ( self )    {
        _duration = duration;
    }
    return self;
}
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return _duration;
}
- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext{
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    if ( fromViewController ) {
        [UIView transitionFromView:fromViewController.view toView:toViewController.view duration:_duration
            options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionOverrideInheritedOptions
            completion:^(BOOL finished) { [transitionContext completeTransition:finished]; }];
    }
    else{
        UIView *toView = toViewController.view;
        CGFloat alpha = toView.alpha;
        toView.alpha = 0;
        
        [UIView animateWithDuration:_duration delay:0 options:UIViewAnimationOptionCurveEaseOut
        animations:^{ toView.alpha = alpha;}
        completion:^(BOOL finished) { [transitionContext completeTransition:finished];}];
    }
}
@end

#import <UIKit/UIGestureRecognizerSubclass.h>

@interface SWRevealViewControllerPanGestureRecognizer : UIPanGestureRecognizer
@end

@implementation SWRevealViewControllerPanGestureRecognizer{
    BOOL _dragging;
    CGPoint _beginPoint;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    [super touchesBegan:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    _beginPoint = [touch locationInView:self.view];
    _dragging = NO;
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    [super touchesMoved:touches withEvent:event];
    
    if ( _dragging || self.state == UIGestureRecognizerStateFailed)
        return;
    
    const CGFloat kDirectionPanThreshold = 5;
    
    UITouch *touch = [touches anyObject];
    CGPoint nowPoint = [touch locationInView:self.view];
    
    if (ABS(nowPoint.x - _beginPoint.x) > kDirectionPanThreshold) _dragging = YES;
    else if (ABS(nowPoint.y - _beginPoint.y) > kDirectionPanThreshold) self.state = UIGestureRecognizerStateFailed;
}
@end

@interface SWRevealViewController()<UIGestureRecognizerDelegate>
{
    SWRevealView *_contentView;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UITapGestureRecognizer *_tapGestureRecognizer;
    FrontViewPosition _frontViewPosition;
    FrontViewPosition _rearViewPosition;
    FrontViewPosition _rightViewPosition;
    SWContextTransitionObject *_rearTransitioningController;
    SWContextTransitionObject *_frontTransitioningController;
    SWContextTransitionObject *_rightTransitioningController;
}
@end

@implementation SWRevealViewController
{
    FrontViewPosition _panInitialFrontPosition;
    NSMutableArray *_animationQueue;
    BOOL _userInteractionStore;
}
const int FrontViewPositionNone = 0xff;

- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if ( self ){
        [self _initDefaultProperties];
    }    
    return self;
}
- (id)init
{
    return [self initWithRearViewController:nil frontViewController:nil];
}
- (id)initWithRearViewController:(UIViewController *)rearViewController frontViewController:(UIViewController *)frontViewController;{
    self = [super init];
    if ( self ){
        [self _initDefaultProperties];
        [self _performTransitionOperation:SWRevealControllerOperationReplaceRearController withViewController:rearViewController animated:NO];
        [self _performTransitionOperation:SWRevealControllerOperationReplaceFrontController withViewController:frontViewController animated:NO];
    }
    return self;
}
- (void)_initDefaultProperties
{
    _frontViewPosition = FrontViewPositionLeft;
    _rearViewPosition = FrontViewPositionLeft;
    _rightViewPosition = FrontViewPositionLeft;
    _rearViewRevealWidth = 260.0f;
    _rearViewRevealOverdraw = 60.0f;
    _rearViewRevealDisplacement = 40.0f;
    _rightViewRevealWidth = 260.0f;
    _rightViewRevealOverdraw = 60.0f;
    _rightViewRevealDisplacement = 40.0f;
    _bounceBackOnOverdraw = YES;
    _bounceBackOnLeftOverdraw = YES;
    _stableDragOnOverdraw = NO;
    _stableDragOnLeftOverdraw = NO;
    _presentFrontViewHierarchically = NO;
    _quickFlickVelocity = 250.0f;
    _toggleAnimationDuration = 0.3;
    _toggleAnimationType = SWRevealToggleAnimationTypeSpring;
    _springDampingRatio = 1;
    _replaceViewAnimationDuration = 0.25;
    _frontViewShadowRadius = 2.5f;
    _frontViewShadowOffset = CGSizeMake(0.0f, 2.5f);
    _frontViewShadowOpacity = 1.0f;
    _frontViewShadowColor = [UIColor blackColor];
    _userInteractionStore = YES;
    _animationQueue = [NSMutableArray array];
    _draggableBorderWidth = 0.0f;
    _clipsViewsToBounds = NO;
    _extendsPointInsideHit = NO;
}
- (UIViewController *)childViewControllerForStatusBarStyle{
    int positionDif =  _frontViewPosition - FrontViewPositionLeft;
    UIViewController *controller = _frontViewController;
    if ( positionDif > 0 ) controller = _rearViewController;
    else if ( positionDif < 0 ) controller = _rightViewController;
    return controller;
}
- (UIViewController *)childViewControllerForStatusBarHidden{
    UIViewController *controller = [self childViewControllerForStatusBarStyle];
    return controller;
}
- (void)loadView{
    [self loadStoryboardControllers];
    CGRect frame = [[UIScreen mainScreen] bounds];
    _contentView = [[SWRevealView alloc] initWithFrame:frame controller:self];
    [_contentView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
    [_contentView setClipsToBounds:_clipsViewsToBounds];
    self.view = _contentView;
    _contentView.backgroundColor = [UIColor blackColor];
    FrontViewPosition initialPosition = _frontViewPosition;
    _frontViewPosition = FrontViewPositionNone;
    _rearViewPosition = FrontViewPositionNone;
    _rightViewPosition = FrontViewPositionNone;
    [self _setFrontViewPosition:initialPosition withDuration:0.0];
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _userInteractionStore = _contentView.userInteractionEnabled;
}
- (NSUInteger)supportedInterfaceOrientations
{
    // we could have simply not implemented this, but we choose to call super to make explicit that we
    // want the default behavior.
    return [super supportedInterfaceOrientations];
}
- (void)setFrontViewController:(UIViewController *)frontViewController{
    [self setFrontViewController:frontViewController animated:NO];
}
- (void)setFrontViewController:(UIViewController *)frontViewController animated:(BOOL)animated{
    if ( ![self isViewLoaded]){
        [self _performTransitionOperation:SWRevealControllerOperationReplaceFrontController withViewController:frontViewController animated:NO];
        return;
    }
    [self _dispatchTransitionOperation:SWRevealControllerOperationReplaceFrontController withViewController:frontViewController animated:animated];
}
- (void)pushFrontViewController:(UIViewController *)frontViewController animated:(BOOL)animated{
    if ( ![self isViewLoaded]){
        [self _performTransitionOperation:SWRevealControllerOperationReplaceFrontController withViewController:frontViewController animated:NO];
        return;
    }
    [self _dispatchPushFrontViewController:frontViewController animated:animated];
}
- (void)setRearViewController:(UIViewController *)rearViewController{
    [self setRearViewController:rearViewController animated:NO];
}
- (void)setRearViewController:(UIViewController *)rearViewController animated:(BOOL)animated{
    if ( ![self isViewLoaded]){
        [self _performTransitionOperation:SWRevealControllerOperationReplaceRearController withViewController:rearViewController animated:NO];
        return;
    }
    [self _dispatchTransitionOperation:SWRevealControllerOperationReplaceRearController withViewController:rearViewController animated:animated];
}
- (void)setRightViewController:(UIViewController *)rightViewController{
    [self setRightViewController:rightViewController animated:NO];
}
- (void)setRightViewController:(UIViewController *)rightViewController animated:(BOOL)animated{
    if ( ![self isViewLoaded]){
        [self _performTransitionOperation:SWRevealControllerOperationReplaceRightController withViewController:rightViewController animated:NO];
        return;
    }
    [self _dispatchTransitionOperation:SWRevealControllerOperationReplaceRightController withViewController:rightViewController animated:animated];
}
- (void)revealToggleAnimated:(BOOL)animated{
    FrontViewPosition toggledFrontViewPosition = FrontViewPositionLeft;
    if (_frontViewPosition <= FrontViewPositionLeft)
        toggledFrontViewPosition = FrontViewPositionRight;
    
    [self setFrontViewPosition:toggledFrontViewPosition animated:animated];
}
- (void)rightRevealToggleAnimated:(BOOL)animated{
    FrontViewPosition toggledFrontViewPosition = FrontViewPositionLeft;
    if (_frontViewPosition >= FrontViewPositionLeft)
        toggledFrontViewPosition = FrontViewPositionLeftSide;
    [self setFrontViewPosition:toggledFrontViewPosition animated:animated];
}
- (void)setFrontViewPosition:(FrontViewPosition)frontViewPosition{
    [self setFrontViewPosition:frontViewPosition animated:NO];
}
- (void)setFrontViewPosition:(FrontViewPosition)frontViewPosition animated:(BOOL)animated{
    if ( ![self isViewLoaded] ){
        _frontViewPosition = frontViewPosition;
        _rearViewPosition = frontViewPosition;
        _rightViewPosition = frontViewPosition;
        return;
    }
    
    [self _dispatchSetFrontViewPosition:frontViewPosition animated:animated];
}
- (void)setFrontViewShadowRadius:(CGFloat)frontViewShadowRadius{
    _frontViewShadowRadius = frontViewShadowRadius;
    [_contentView reloadShadow];
}
- (void)setFrontViewShadowOffset:(CGSize)frontViewShadowOffset
{
    _frontViewShadowOffset = frontViewShadowOffset;
    [_contentView reloadShadow];
}
- (void)setFrontViewShadowOpacity:(CGFloat)frontViewShadowOpacity{
    _frontViewShadowOpacity = frontViewShadowOpacity;
    [_contentView reloadShadow];
}
- (void)setFrontViewShadowColor:(UIColor *)frontViewShadowColor{
    _frontViewShadowColor = frontViewShadowColor;
    [_contentView reloadShadow];
}
- (UIPanGestureRecognizer*)panGestureRecognizer{
    if ( _panGestureRecognizer == nil ){
        _panGestureRecognizer = [[SWRevealViewControllerPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleRevealGesture:)];
        _panGestureRecognizer.delegate = self;
        [_contentView.frontView addGestureRecognizer:_panGestureRecognizer];
    }
    return _panGestureRecognizer;
}
- (UITapGestureRecognizer*)tapGestureRecognizer{
    if ( _tapGestureRecognizer == nil ){
        UITapGestureRecognizer *tapRecognizer =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTapGesture:)];
        
        tapRecognizer.delegate = self;
        [_contentView.frontView addGestureRecognizer:tapRecognizer];
        _tapGestureRecognizer = tapRecognizer ;
    }
    return _tapGestureRecognizer;
}
- (void)setClipsViewsToBounds:(BOOL)clipsViewsToBounds{
    _clipsViewsToBounds = clipsViewsToBounds;
    [_contentView setClipsToBounds:clipsViewsToBounds];
}

- (IBAction)revealToggle:(id)sender{
    [self revealToggleAnimated:YES];
}
- (IBAction)rightRevealToggle:(id)sender{
    [self rightRevealToggleAnimated:YES];
}
- (void)_disableUserInteraction{
    [_contentView setUserInteractionEnabled:NO];
    [_contentView setDisableLayout:YES];
}
- (void)_restoreUserInteraction{
    [_contentView setUserInteractionEnabled:_userInteractionStore];
    [_contentView setDisableLayout:NO];
}

- (void)_notifyPanGestureBegan
{
    if ( [_delegate respondsToSelector:@selector(revealControllerPanGestureBegan:)] )
        [_delegate revealControllerPanGestureBegan:self];
    CGFloat xLocation, dragProgress, overProgress;
    [self _getDragLocation:&xLocation progress:&dragProgress overdrawProgress:&overProgress];
    if ( [_delegate respondsToSelector:@selector(revealController:panGestureBeganFromLocation:progress:overProgress:)] )
        [_delegate revealController:self panGestureBeganFromLocation:xLocation progress:dragProgress overProgress:overProgress];
    else if ( [_delegate respondsToSelector:@selector(revealController:panGestureBeganFromLocation:progress:)] )
        [_delegate revealController:self panGestureBeganFromLocation:xLocation progress:dragProgress];
}
- (void)_notifyPanGestureMoved{
    CGFloat xLocation, dragProgress, overProgress;
    [self _getDragLocation:&xLocation progress:&dragProgress overdrawProgress:&overProgress];
    if ( [_delegate respondsToSelector:@selector(revealController:panGestureMovedToLocation:progress:overProgress:)] )
        [_delegate revealController:self panGestureMovedToLocation:xLocation progress:dragProgress overProgress:overProgress];
    else if ( [_delegate respondsToSelector:@selector(revealController:panGestureMovedToLocation:progress:)] )
        [_delegate revealController:self panGestureMovedToLocation:xLocation progress:dragProgress];
}
- (void)_notifyPanGestureEnded{
    CGFloat xLocation, dragProgress, overProgress;
    [self _getDragLocation:&xLocation progress:&dragProgress overdrawProgress:&overProgress];
    if ( [_delegate respondsToSelector:@selector(revealController:panGestureEndedToLocation:progress:overProgress:)] )
        [_delegate revealController:self panGestureEndedToLocation:xLocation progress:dragProgress overProgress:overProgress];
    else if ( [_delegate respondsToSelector:@selector(revealController:panGestureEndedToLocation:progress:)] )
        [_delegate revealController:self panGestureEndedToLocation:xLocation progress:dragProgress];
    if ( [_delegate respondsToSelector:@selector(revealControllerPanGestureEnded:)] )
        [_delegate revealControllerPanGestureEnded:self];
}
- (void)_getRevealWidth:(CGFloat*)pRevealWidth revealOverDraw:(CGFloat*)pRevealOverdraw forSymetry:(int)symetry{
    if ( symetry < 0 ) *pRevealWidth = _rightViewRevealWidth, *pRevealOverdraw = _rightViewRevealOverdraw;
    else *pRevealWidth = _rearViewRevealWidth, *pRevealOverdraw = _rearViewRevealOverdraw;
    
    if (*pRevealWidth < 0) *pRevealWidth = _contentView.bounds.size.width + *pRevealWidth;
}
- (void)_getBounceBack:(BOOL*)pBounceBack pStableDrag:(BOOL*)pStableDrag forSymetry:(int)symetry{
    if ( symetry < 0 ) *pBounceBack = _bounceBackOnLeftOverdraw, *pStableDrag = _stableDragOnLeftOverdraw;
    else *pBounceBack = _bounceBackOnOverdraw, *pStableDrag = _stableDragOnOverdraw;
}

- (void)_getAdjustedFrontViewPosition:(FrontViewPosition*)frontViewPosition forSymetry:(int)symetry{
    if ( symetry < 0 ) *frontViewPosition = FrontViewPositionLeft + symetry*(*frontViewPosition-FrontViewPositionLeft);
}
- (void)_getDragLocationx:(CGFloat*)xLocation progress:(CGFloat*)progress{
    UIView *frontView = _contentView.frontView;
    *xLocation = frontView.frame.origin.x;

    int symetry = *xLocation<0 ? -1 : 1;
    
    CGFloat xWidth = symetry < 0 ? _rightViewRevealWidth : _rearViewRevealWidth;
    if ( xWidth < 0 ) xWidth = _contentView.bounds.size.width + xWidth;
    
    *progress = *xLocation/xWidth * symetry;
}
- (void)_getDragLocation:(CGFloat*)xLocation progress:(CGFloat*)progress overdrawProgress:(CGFloat*)overProgress{
    UIView *frontView = _contentView.frontView;
    *xLocation = frontView.frame.origin.x;

    int symetry = *xLocation<0 ? -1 : 1;
    
    CGFloat xWidth = symetry < 0 ? _rightViewRevealWidth : _rearViewRevealWidth;
    CGFloat xOverWidth = symetry < 0 ? _rightViewRevealOverdraw : _rearViewRevealOverdraw;
    
    if ( xWidth < 0 ) xWidth = _contentView.bounds.size.width + xWidth;
    
    *progress = *xLocation*symetry/xWidth;
    *overProgress = (*xLocation*symetry-xWidth)/xOverWidth;
}
#define _enqueue(code) [self _enqueueBlock:^{code;}];

- (void)_enqueueBlock:(void (^)(void))block
{
    [_animationQueue insertObject:block atIndex:0];
    if ( _animationQueue.count == 1){
        block();
    }
}
- (void)_dequeue{
    [_animationQueue removeLastObject];

    if ( _animationQueue.count > 0 ){
        void (^block)(void) = [_animationQueue lastObject];
        block();
    }
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
    if ( _animationQueue.count == 0 )
    {
        if ( recognizer == _panGestureRecognizer )
            return [self _panGestureShouldBegin];
        
        if ( recognizer == _tapGestureRecognizer )
            return [self _tapGestureShouldBegin];
    }
    return NO;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    if ( gestureRecognizer == _panGestureRecognizer ){
        if ( [_delegate respondsToSelector:@selector(revealController:panGestureRecognizerShouldRecognizeSimultaneouslyWithGestureRecognizer:)] )
            if ( [_delegate revealController:self panGestureRecognizerShouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer] != NO )
                return YES;
    }
    if ( gestureRecognizer == _tapGestureRecognizer ){
        if ( [_delegate respondsToSelector:@selector(revealController:tapGestureRecognizerShouldRecognizeSimultaneouslyWithGestureRecognizer:)] )
            if ( [_delegate revealController:self tapGestureRecognizerShouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer] != NO )
                return YES;
    }
    
    return NO;
}
- (BOOL)_tapGestureShouldBegin
{
    if ( _frontViewPosition == FrontViewPositionLeft ||
        _frontViewPosition == FrontViewPositionRightMostRemoved ||
        _frontViewPosition == FrontViewPositionLeftSideMostRemoved )
            return NO;
    if ( [_delegate respondsToSelector:@selector(revealControllerTapGestureShouldBegin:)] )
        if ( [_delegate revealControllerTapGestureShouldBegin:self] == NO )
            return NO;
    
    return YES;
}
- (BOOL)_panGestureShouldBegin
{
    UIView *recognizerView = _panGestureRecognizer.view;
    CGPoint translation = [_panGestureRecognizer translationInView:recognizerView];
    if ( [_delegate respondsToSelector:@selector(revealControllerPanGestureShouldBegin:)] )
        if ( [_delegate revealControllerPanGestureShouldBegin:self] == NO )
            return NO;    CGFloat xLocation = [_panGestureRecognizer locationInView:recognizerView].x;
    CGFloat width = recognizerView.bounds.size.width;
    
    BOOL draggableBorderAllowing = (
         /*_frontViewPosition != FrontViewPositionLeft ||*/ _draggableBorderWidth == 0.0f ||
         (_rearViewController && xLocation <= _draggableBorderWidth) ||
         (_rightViewController && xLocation >= (width - _draggableBorderWidth)) );
    BOOL translationForbidding = ( _frontViewPosition == FrontViewPositionLeft &&
        ((_rearViewController == nil && translation.x > 0) || (_rightViewController == nil && translation.x < 0)) );
    return draggableBorderAllowing && !translationForbidding ;
}
- (void)_handleTapGesture:(UITapGestureRecognizer *)recognizer
{
    NSTimeInterval duration = _toggleAnimationDuration;
    [self _setFrontViewPosition:FrontViewPositionLeft withDuration:duration];
}
- (void)_handleRevealGesture:(UIPanGestureRecognizer *)recognizer{
    switch ( recognizer.state ){
        case UIGestureRecognizerStateBegan:
            [self _handleRevealGestureStateBeganWithRecognizer:recognizer];
            break;
            
        case UIGestureRecognizerStateChanged:
            [self _handleRevealGestureStateChangedWithRecognizer:recognizer];
            break;
            
        case UIGestureRecognizerStateEnded:
            [self _handleRevealGestureStateEndedWithRecognizer:recognizer];
            break;
            
        case UIGestureRecognizerStateCancelled:
            [self _handleRevealGestureStateCancelledWithRecognizer:recognizer];
            break;
            
        default:
            break;
    }
}
- (void)_handleRevealGestureStateBeganWithRecognizer:(UIPanGestureRecognizer *)recognizer{
    [self _enqueueBlock:^{}];
    _panInitialFrontPosition = _frontViewPosition;
    [self _disableUserInteraction];
    [self _notifyPanGestureBegan];
}
- (void)_handleRevealGestureStateChangedWithRecognizer:(UIPanGestureRecognizer *)recognizer{
    CGFloat translation = [recognizer translationInView:_contentView].x;
    CGFloat baseLocation = [_contentView frontLocationForPosition:_panInitialFrontPosition];
    CGFloat xLocation = baseLocation + translation;
    if ( xLocation < 0 ){
        if ( _rightViewController == nil ) xLocation = 0;
        [self _rightViewDeploymentForNewFrontViewPosition:FrontViewPositionLeftSide]();
        [self _rearViewDeploymentForNewFrontViewPosition:FrontViewPositionLeftSide]();
    }
    if ( xLocation > 0 ){
        if ( _rearViewController == nil ) xLocation = 0;
        [self _rightViewDeploymentForNewFrontViewPosition:FrontViewPositionRight]();
        [self _rearViewDeploymentForNewFrontViewPosition:FrontViewPositionRight]();
    }
    [_contentView dragFrontViewToXLocation:xLocation];
    [self _notifyPanGestureMoved];
}
- (void)_handleRevealGestureStateEndedWithRecognizer:(UIPanGestureRecognizer *)recognizer{
    UIView *frontView = _contentView.frontView;
    CGFloat xLocation = frontView.frame.origin.x;
    CGFloat velocity = [recognizer velocityInView:_contentView].x;
    int symetry = xLocation<0 ? -1 : 1;
    CGFloat revealWidth ;
    CGFloat revealOverdraw ;
    BOOL bounceBack;
    BOOL stableDrag;
    [self _getRevealWidth:&revealWidth revealOverDraw:&revealOverdraw forSymetry:symetry];
    [self _getBounceBack:&bounceBack pStableDrag:&stableDrag forSymetry:symetry];
    xLocation = xLocation * symetry;
    FrontViewPosition frontViewPosition = FrontViewPositionLeft;
    NSTimeInterval duration = _toggleAnimationDuration;

    if (ABS(velocity) > _quickFlickVelocity){
        CGFloat journey = xLocation;
        if (velocity*symetry > 0.0f){
            frontViewPosition = FrontViewPositionRight;
            journey = revealWidth - xLocation;
            if (xLocation > revealWidth){
                if (!bounceBack && stableDrag /*&& xPosition > _rearViewRevealWidth+_rearViewRevealOverdraw*0.5f*/){
                    frontViewPosition = FrontViewPositionRightMost;
                    journey = revealWidth+revealOverdraw - xLocation;
                }
            }
        }
        duration = ABS(journey/velocity);
    }
    else {
        if (xLocation > revealWidth*0.5f) {
            frontViewPosition = FrontViewPositionRight;
            if (xLocation > revealWidth) {
                if (bounceBack)
                    frontViewPosition = FrontViewPositionLeft;
                else if (stableDrag && xLocation > revealWidth+revealOverdraw*0.5f)
                    frontViewPosition = FrontViewPositionRightMost;
            }
        }
    }
    [self _getAdjustedFrontViewPosition:&frontViewPosition forSymetry:symetry];
    [self _restoreUserInteraction];
    [self _notifyPanGestureEnded];
    [self _setFrontViewPosition:frontViewPosition withDuration:duration];
}
- (void)_handleRevealGestureStateCancelledWithRecognizer:(UIPanGestureRecognizer *)recognizer {
    [self _restoreUserInteraction];
    [self _notifyPanGestureEnded];
    [self _dequeue];
}
- (void)_dispatchSetFrontViewPosition:(FrontViewPosition)frontViewPosition animated:(BOOL)animated {
    NSTimeInterval duration = animated?_toggleAnimationDuration:0.0;
    __weak SWRevealViewController *theSelf = self;
    _enqueue( [theSelf _setFrontViewPosition:frontViewPosition withDuration:duration] );
}
- (void)_dispatchPushFrontViewController:(UIViewController *)newFrontViewController animated:(BOOL)animated {
    FrontViewPosition preReplacementPosition = FrontViewPositionLeft;
    if ( _frontViewPosition > FrontViewPositionLeft ) preReplacementPosition = FrontViewPositionRightMost;
    if ( _frontViewPosition < FrontViewPositionLeft ) preReplacementPosition = FrontViewPositionLeftSideMost;
    
    NSTimeInterval duration = animated?_toggleAnimationDuration:0.0;
    NSTimeInterval firstDuration = duration;
    NSInteger initialPosDif = ABS( _frontViewPosition - preReplacementPosition );
    if ( initialPosDif == 1 ) firstDuration *= 0.8;
    else if ( initialPosDif == 0 ) firstDuration = 0;
    __weak SWRevealViewController *theSelf = self;
    if ( animated ) {
        _enqueue( [theSelf _setFrontViewPosition:preReplacementPosition withDuration:firstDuration] );
        _enqueue( [theSelf _performTransitionOperation:SWRevealControllerOperationReplaceFrontController withViewController:newFrontViewController animated:NO] );
        _enqueue( [theSelf _setFrontViewPosition:FrontViewPositionLeft withDuration:duration] );
    }
    else {
        _enqueue( [theSelf _performTransitionOperation:SWRevealControllerOperationReplaceFrontController withViewController:newFrontViewController animated:NO] );
    }
}
- (void)_dispatchTransitionOperation:(SWRevealControllerOperation)operation withViewController:(UIViewController *)newViewController animated:(BOOL)animated
{
    __weak SWRevealViewController *theSelf = self;
    _enqueue( [theSelf _performTransitionOperation:operation withViewController:newViewController animated:animated] );
}
- (void)_setFrontViewPosition:(FrontViewPosition)newPosition withDuration:(NSTimeInterval)duration
{
    void (^rearDeploymentCompletion)() = [self _rearViewDeploymentForNewFrontViewPosition:newPosition];
    void (^rightDeploymentCompletion)() = [self _rightViewDeploymentForNewFrontViewPosition:newPosition];
    void (^frontDeploymentCompletion)() = [self _frontViewDeploymentForNewFrontViewPosition:newPosition];
    
    void (^animations)() = ^() {
        [self setNeedsStatusBarAppearanceUpdate];
        [_contentView layoutSubviews];
        if ([_delegate respondsToSelector:@selector(revealController:animateToPosition:)])
            [_delegate revealController:self animateToPosition:_frontViewPosition];
    };
    void (^completion)(BOOL) = ^(BOOL finished) {
        rearDeploymentCompletion();
        rightDeploymentCompletion();
        frontDeploymentCompletion();
        [self _dequeue];
    };
    if ( duration > 0.0 )
    {
        if ( _toggleAnimationType == SWRevealToggleAnimationTypeEaseOut ) {
            [UIView animateWithDuration:duration delay:0.0
            options:UIViewAnimationOptionCurveEaseOut animations:animations completion:completion];
        }
        else {
            [UIView animateWithDuration:_toggleAnimationDuration delay:0.0 usingSpringWithDamping:_springDampingRatio initialSpringVelocity:1/duration
            options:0 animations:animations completion:completion];
        }
    }
    else
    {
        animations();
        completion(YES);
    }
}
- (void)_performTransitionOperation:(SWRevealControllerOperation)operation withViewController:(UIViewController*)new animated:(BOOL)animated
{
    if ( [_delegate respondsToSelector:@selector(revealController:willAddViewController:forOperation:animated:)] )
        [_delegate revealController:self willAddViewController:new forOperation:operation animated:animated];
    UIViewController *old = nil;
    UIView *view = nil;
    if ( operation == SWRevealControllerOperationReplaceRearController )
        old = _rearViewController, _rearViewController = new, view = _contentView.rearView;
    else if ( operation == SWRevealControllerOperationReplaceFrontController )
        old = _frontViewController, _frontViewController = new, view = _contentView.frontView;
    else if ( operation == SWRevealControllerOperationReplaceRightController )
        old = _rightViewController, _rightViewController = new, view = _contentView.rightView;
    void (^completion)() = [self _transitionFromViewController:old toViewController:new inView:view];
    
    void (^animationCompletion)() = ^
    {
        completion();
        if ( [_delegate respondsToSelector:@selector(revealController:didAddViewController:forOperation:animated:)] )
            [_delegate revealController:self didAddViewController:new forOperation:operation animated:animated];
        [self _dequeue];
    };
    
    if ( animated )
    {
        id<UIViewControllerAnimatedTransitioning> animationController = nil;
    
        if ( [_delegate respondsToSelector:@selector(revealController:animationControllerForOperation:fromViewController:toViewController:)] )
            animationController = [_delegate revealController:self animationControllerForOperation:operation fromViewController:old toViewController:new];
        if ( !animationController )
            animationController = [[SWDefaultAnimationController alloc] initWithDuration:_replaceViewAnimationDuration];
        SWContextTransitionObject *transitioningObject = [[SWContextTransitionObject alloc] initWithRevealController:self containerView:view
            fromVC:old toVC:new completion:animationCompletion];
    
        if ( [animationController transitionDuration:transitioningObject] > 0 )
            [animationController animateTransition:transitioningObject];
        else
            animationCompletion();
    }
    else {
        animationCompletion();
    }
}
- (void (^)(void))_frontViewDeploymentForNewFrontViewPosition:(FrontViewPosition)newPosition
{
    if ( (_rightViewController == nil && newPosition < FrontViewPositionLeft) ||
         (_rearViewController == nil && newPosition > FrontViewPositionLeft) )
        newPosition = FrontViewPositionLeft;
    
    BOOL positionIsChanging = (_frontViewPosition != newPosition);
    
    BOOL appear =
        (_frontViewPosition >= FrontViewPositionRightMostRemoved || _frontViewPosition <= FrontViewPositionLeftSideMostRemoved || _frontViewPosition == FrontViewPositionNone) &&
        (newPosition < FrontViewPositionRightMostRemoved && newPosition > FrontViewPositionLeftSideMostRemoved);
    
    BOOL disappear =
        (newPosition >= FrontViewPositionRightMostRemoved || newPosition <= FrontViewPositionLeftSideMostRemoved ) &&
        (_frontViewPosition < FrontViewPositionRightMostRemoved && _frontViewPosition > FrontViewPositionLeftSideMostRemoved && _frontViewPosition != FrontViewPositionNone);
    
    if ( positionIsChanging ) {
        if ( [_delegate respondsToSelector:@selector(revealController:willMoveToPosition:)] )
            [_delegate revealController:self willMoveToPosition:newPosition];
    }
    
    _frontViewPosition = newPosition;
    void (^deploymentCompletion)() =
        [self _deploymentForViewController:_frontViewController inView:_contentView.frontView appear:appear disappear:disappear];
    void (^completion)() = ^()
    {
        deploymentCompletion();
        if ( positionIsChanging ) {
            if ( [_delegate respondsToSelector:@selector(revealController:didMoveToPosition:)] )
                [_delegate revealController:self didMoveToPosition:newPosition];
        }
    };
    return completion;
}
- (void (^)(void))_rearViewDeploymentForNewFrontViewPosition:(FrontViewPosition)newPosition
{
    if ( _presentFrontViewHierarchically )
        newPosition = FrontViewPositionRight;
    if ( _rearViewController == nil && newPosition > FrontViewPositionLeft )
        newPosition = FrontViewPositionLeft;
    BOOL appear = (_rearViewPosition <= FrontViewPositionLeft || _rearViewPosition == FrontViewPositionNone) && newPosition > FrontViewPositionLeft;
    BOOL disappear = newPosition <= FrontViewPositionLeft && (_rearViewPosition > FrontViewPositionLeft && _rearViewPosition != FrontViewPositionNone);
    if ( appear )
        [_contentView prepareRearViewForPosition:newPosition];
    _rearViewPosition = newPosition;
    void (^deploymentCompletion)() =
        [self _deploymentForViewController:_rearViewController inView:_contentView.rearView appear:appear disappear:disappear];
    void (^completion)() = ^() {
        deploymentCompletion();
        if ( disappear )
            [_contentView unloadRearView];
    };
    return completion;
}
- (void (^)(void))_rightViewDeploymentForNewFrontViewPosition:(FrontViewPosition)newPosition
{
    if ( _rightViewController == nil && newPosition < FrontViewPositionLeft )
        newPosition = FrontViewPositionLeft;
    BOOL appear = (_rightViewPosition >= FrontViewPositionLeft || _rightViewPosition == FrontViewPositionNone) && newPosition < FrontViewPositionLeft ;
    BOOL disappear = newPosition >= FrontViewPositionLeft && (_rightViewPosition < FrontViewPositionLeft && _rightViewPosition != FrontViewPositionNone);
    if ( appear )
        [_contentView prepareRightViewForPosition:newPosition];
    _rightViewPosition = newPosition;

    void (^deploymentCompletion)() =
        [self _deploymentForViewController:_rightViewController inView:_contentView.rightView appear:appear disappear:disappear];
    void (^completion)() = ^() {
        deploymentCompletion();
        if ( disappear )
            [_contentView unloadRightView];
    };
    return completion;
}
- (void (^)(void)) _deploymentForViewController:(UIViewController*)controller inView:(UIView*)view appear:(BOOL)appear disappear:(BOOL)disappear {
    if ( appear ) return [self _deployForViewController:controller inView:view];
    if ( disappear ) return [self _undeployForViewController:controller];
    return ^{};
}
- (void (^)(void))_deployForViewController:(UIViewController*)controller inView:(UIView*)view {
    if ( !controller || !view )
        return ^(void){};
    CGRect frame = view.bounds;
    UIView *controllerView = controller.view;
    controllerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    controllerView.frame = frame;
    
    if ( [controllerView isKindOfClass:[UIScrollView class]] )
    {
        BOOL adjust = controller.automaticallyAdjustsScrollViewInsets;
        if ( adjust ) {
            [(id)controllerView setContentInset:UIEdgeInsetsMake(statusBarAdjustment(_contentView), 0, 0, 0)];
        }
    }
    [view addSubview:controllerView];
    void (^completionBlock)(void) = ^(void)
    {
    };
    return completionBlock;
}
- (void (^)(void))_undeployForViewController:(UIViewController*)controller
{
    if (!controller)
        return ^(void){};
    void (^completionBlock)(void) = ^(void) {
        [controller.view removeFromSuperview];
    };
    return completionBlock;
}
- (void(^)(void))_transitionFromViewController:(UIViewController*)fromController toViewController:(UIViewController*)toController inView:(UIView*)view
{
    if ( fromController == toController )
        return ^(void){};
    if ( toController ) [self addChildViewController:toController];
    void (^deployCompletion)() = [self _deployForViewController:toController inView:view];
    [fromController willMoveToParentViewController:nil];
    void (^undeployCompletion)() = [self _undeployForViewController:fromController];
    void (^completionBlock)(void) = ^(void)
    {
        undeployCompletion() ;
        [fromController removeFromParentViewController];
        deployCompletion() ;
        [toController didMoveToParentViewController:self];
    };
    return completionBlock;
}
- (void)loadStoryboardControllers
{
    if ( self.storyboard && _rearViewController == nil )
    {
        @try {
            [self performSegueWithIdentifier:SWSegueRearIdentifier sender:nil];
        }
        @catch(NSException *exception) {}
        
        @try {
            [self performSegueWithIdentifier:SWSegueFrontIdentifier sender:nil];
        }
        @catch(NSException *exception) {}
        
        @try {
            [self performSegueWithIdentifier:SWSegueRightIdentifier sender:nil];
        }
        @catch(NSException *exception) {}
    }
}
+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder*)coder
{
    SWRevealViewController* vc = nil;
    UIStoryboard* sb = [coder decodeObjectForKey:UIStateRestorationViewControllerStoryboardKey];
    if (sb)
    {
        vc = (SWRevealViewController*)[sb instantiateViewControllerWithIdentifier:@"SWRevealViewController"];
        vc.restorationIdentifier = [identifierComponents lastObject];
        vc.restorationClass = [SWRevealViewController class];
    }
    return vc;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_rearViewRevealWidth forKey:@"_rearViewRevealWidth"];
    [coder encodeDouble:_rearViewRevealOverdraw forKey:@"_rearViewRevealOverdraw"];
    [coder encodeDouble:_rearViewRevealDisplacement forKey:@"_rearViewRevealDisplacement"];
    [coder encodeDouble:_rightViewRevealWidth forKey:@"_rightViewRevealWidth"];
    [coder encodeDouble:_rightViewRevealOverdraw forKey:@"_rightViewRevealOverdraw"];
    [coder encodeDouble:_rightViewRevealDisplacement forKey:@"_rightViewRevealDisplacement"];
    [coder encodeBool:_bounceBackOnOverdraw forKey:@"_bounceBackOnOverdraw"];
    [coder encodeBool:_bounceBackOnLeftOverdraw forKey:@"_bounceBackOnLeftOverdraw"];
    [coder encodeBool:_stableDragOnOverdraw forKey:@"_stableDragOnOverdraw"];
    [coder encodeBool:_stableDragOnLeftOverdraw forKey:@"_stableDragOnLeftOverdraw"];
    [coder encodeBool:_presentFrontViewHierarchically forKey:@"_presentFrontViewHierarchically"];
    [coder encodeDouble:_quickFlickVelocity forKey:@"_quickFlickVelocity"];
    [coder encodeDouble:_toggleAnimationDuration forKey:@"_toggleAnimationDuration"];
    [coder encodeInteger:_toggleAnimationType forKey:@"_toggleAnimationType"];
    [coder encodeDouble:_springDampingRatio forKey:@"_springDampingRatio"];
    [coder encodeDouble:_replaceViewAnimationDuration forKey:@"_replaceViewAnimationDuration"];
    [coder encodeDouble:_frontViewShadowRadius forKey:@"_frontViewShadowRadius"];
    [coder encodeCGSize:_frontViewShadowOffset forKey:@"_frontViewShadowOffset"];
    [coder encodeDouble:_frontViewShadowOpacity forKey:@"_frontViewShadowOpacity"];
    [coder encodeObject:_frontViewShadowColor forKey:@"_frontViewShadowColor"];
    [coder encodeBool:_userInteractionStore forKey:@"_userInteractionStore"];
    [coder encodeDouble:_draggableBorderWidth forKey:@"_draggableBorderWidth"];
    [coder encodeBool:_clipsViewsToBounds forKey:@"_clipsViewsToBounds"];
    [coder encodeBool:_extendsPointInsideHit forKey:@"_extendsPointInsideHit"];
    [coder encodeObject:_rearViewController forKey:@"_rearViewController"];
    [coder encodeObject:_frontViewController forKey:@"_frontViewController"];
    [coder encodeObject:_rightViewController forKey:@"_rightViewController"];
    [coder encodeInteger:_frontViewPosition  forKey:@"_frontViewPosition"];
    [super encodeRestorableStateWithCoder:coder];
}
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    _rearViewRevealWidth = [coder decodeDoubleForKey:@"_rearViewRevealWidth"];
    _rearViewRevealOverdraw = [coder decodeDoubleForKey:@"_rearViewRevealOverdraw"];
    _rearViewRevealDisplacement = [coder decodeDoubleForKey:@"_rearViewRevealDisplacement"];
    _rightViewRevealWidth = [coder decodeDoubleForKey:@"_rightViewRevealWidth"];
    _rightViewRevealOverdraw = [coder decodeDoubleForKey:@"_rightViewRevealOverdraw"];
    _rightViewRevealDisplacement = [coder decodeDoubleForKey:@"_rightViewRevealDisplacement"];
    _bounceBackOnOverdraw = [coder decodeBoolForKey:@"_bounceBackOnOverdraw"];
    _bounceBackOnLeftOverdraw = [coder decodeBoolForKey:@"_bounceBackOnLeftOverdraw"];
    _stableDragOnOverdraw = [coder decodeBoolForKey:@"_stableDragOnOverdraw"];
    _stableDragOnLeftOverdraw = [coder decodeBoolForKey:@"_stableDragOnLeftOverdraw"];
    _presentFrontViewHierarchically = [coder decodeBoolForKey:@"_presentFrontViewHierarchically"];
    _quickFlickVelocity = [coder decodeDoubleForKey:@"_quickFlickVelocity"];
    _toggleAnimationDuration = [coder decodeDoubleForKey:@"_toggleAnimationDuration"];
    _toggleAnimationType = [coder decodeIntegerForKey:@"_toggleAnimationType"];
    _springDampingRatio = [coder decodeDoubleForKey:@"_springDampingRatio"];
    _replaceViewAnimationDuration = [coder decodeDoubleForKey:@"_replaceViewAnimationDuration"];
    _frontViewShadowRadius = [coder decodeDoubleForKey:@"_frontViewShadowRadius"];
    _frontViewShadowOffset = [coder decodeCGSizeForKey:@"_frontViewShadowOffset"];
    _frontViewShadowOpacity = [coder decodeDoubleForKey:@"_frontViewShadowOpacity"];
    _frontViewShadowColor = [coder decodeObjectForKey:@"_frontViewShadowColor"];
    _userInteractionStore = [coder decodeBoolForKey:@"_userInteractionStore"];
    _animationQueue = [NSMutableArray array];
    _draggableBorderWidth = [coder decodeDoubleForKey:@"_draggableBorderWidth"];
    _clipsViewsToBounds = [coder decodeBoolForKey:@"_clipsViewsToBounds"];
    _extendsPointInsideHit = [coder decodeBoolForKey:@"_extendsPointInsideHit"];
    [self setRearViewController:[coder decodeObjectForKey:@"_rearViewController"]];
    [self setFrontViewController:[coder decodeObjectForKey:@"_frontViewController"]];
    [self setRightViewController:[coder decodeObjectForKey:@"_rightViewController"]];
    [self setFrontViewPosition:[coder decodeIntForKey: @"_frontViewPosition"]];
    [super decodeRestorableStateWithCoder:coder];
}
- (void)applicationFinishedRestoringState
{
}
@end

@implementation UIViewController(SWRevealViewController)

- (SWRevealViewController*)revealViewController
{
    UIViewController *parent = self;
    Class revealClass = [SWRevealViewController class];
    while ( nil != (parent = [parent parentViewController]) && ![parent isKindOfClass:revealClass] ) {}
    return (id)parent;
}
@end

NSString * const SWSegueRearIdentifier = @"sw_rear";
NSString * const SWSegueFrontIdentifier = @"sw_front";
NSString * const SWSegueRightIdentifier = @"sw_right";

@implementation SWRevealViewControllerSegueSetController

- (void)perform
{
    SWRevealControllerOperation operation = SWRevealControllerOperationNone;
    NSString *identifier = self.identifier;
    SWRevealViewController *rvc = self.sourceViewController;
    UIViewController *dvc = self.destinationViewController;
    
    if ( [identifier isEqualToString:SWSegueFrontIdentifier] )
        operation = SWRevealControllerOperationReplaceFrontController;
    else if ( [identifier isEqualToString:SWSegueRearIdentifier] )
        operation = SWRevealControllerOperationReplaceRearController;
    else if ( [identifier isEqualToString:SWSegueRightIdentifier] )
        operation = SWRevealControllerOperationReplaceRightController;
    if ( operation != SWRevealControllerOperationNone )
        [rvc _performTransitionOperation:operation withViewController:dvc animated:NO];
}
@end
@implementation SWRevealViewControllerSeguePushController
- (void)perform
{
    SWRevealViewController *rvc = [self.sourceViewController revealViewController];
    UIViewController *dvc = self.destinationViewController;
    [rvc pushFrontViewController:dvc animated:YES];
}
@end
