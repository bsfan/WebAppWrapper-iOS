//
//  RootViewController.m
//  WebAppWrapper
//
//  Created by Alex Rezit on 22/05/2013.
//  Copyright (c) 2013 Seymour Dev. All rights reserved.
//

#import "RootViewController.h"
#import "RWebViewController.h"

NSString * const kWebAppStartLink = @"http://v2ex.com/";
NSString * const kWebAppHost = @"v2ex.com";
NSUInteger const kWebAppMaxFailRefreshCount = 3;

@interface RootViewController () <UIWebViewDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) NSURL *startURL;
@property (nonatomic, strong) NSString *webAppHost;
@property (nonatomic, strong) NSArray *otherInternalHosts;
@property (nonatomic, strong) NSArray *blockedHosts;

@property (nonatomic, assign) BOOL shouldCheckAuthenticity;
@property (nonatomic, strong) NSString *authenticityCheckQueryJavaScript;
@property (nonatomic, strong) NSString *authenticityCheckResult;

@property (nonatomic, assign) NSUInteger currentFailRefreshCount;
@property (nonatomic, assign) NSUInteger maxFailRefreshCount;
@property (nonatomic, weak) UIAlertView *failLoadAlertView;

@property (nonatomic, strong) UIWebView *webView;

- (void)showFailLoadWarning;

- (void)loadStartPage;
- (void)refresh;
- (void)failRefresh;

- (void)configure;

@end

@implementation RootViewController

#pragma mark - View control

- (void)showFailLoadWarning
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                    message:NSLocalizedString(@"An error occurred on loading.", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Quit", nil)
                                          otherButtonTitles:NSLocalizedString(@"Retry", nil), nil];
    alertView.delegate = self;
    self.failLoadAlertView = alertView;
    [alertView show];
}

#pragma mark - Web view control

- (void)loadStartPage
{
    NSURLRequest *request = [NSURLRequest requestWithURL:self.startURL];
    [self.webView loadRequest:request];
}

- (void)refresh
{
    [self.webView reload];
}

- (void)failRefresh
{
    if (self.currentFailRefreshCount) {
        [self refresh];
        self.currentFailRefreshCount--;
    } else {
        [self showFailLoadWarning];
    }
}

- (void)resetFailRefreshCount
{
    self.currentFailRefreshCount = self.maxFailRefreshCount;
}

#pragma mark - Life cycle

- (void)configure
{
    // Init start URL.
    
    self.startURL = [NSURL URLWithString:kWebAppStartLink];
    
    // Set web app host.
    
    self.webAppHost = kWebAppHost;
    
    // Set other internal hosts.
    
    self.otherInternalHosts = @[
                                @"googleads.g.doubleclick.net",
                                @"metric.gstatic.com"
                                ];
    
    // Set blocked hosts.
    
    self.blockedHosts = @[
                          @"about:blank"
                          ];
    
    // Set max fail refresh count.
    
    self.maxFailRefreshCount = kWebAppMaxFailRefreshCount;
    [self resetFailRefreshCount];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self configure];
    
    // Init & add web view.
    
    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
    self.webView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleHeight);
    [self.view addSubview:self.webView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!self.webView.request) {
        [self loadStartPage];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Web view delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (webView == self.webView) {
        NSString *host = request.URL.host;
        
        // Determine if the URL is blocked.
        
        __block BOOL isBlocked = NO;
        [self.blockedHosts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *blockedHost = obj;
            if (NSMaxRange([host rangeOfString:blockedHost options:(NSCaseInsensitiveSearch | NSBackwardsSearch)]) == host.length) {
                isBlocked = YES;
                *stop = YES;
            }
        }];
        
        // Determine if the URL is external.
        
        __block BOOL isExternal = NO;
        if (!isBlocked) {
            if (NSMaxRange([host rangeOfString:self.webAppHost options:(NSCaseInsensitiveSearch | NSBackwardsSearch)]) != host.length) {
                isExternal = YES;
                [self.otherInternalHosts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    NSString *internalHost = obj;
                    if (NSMaxRange([host rangeOfString:internalHost options:(NSCaseInsensitiveSearch | NSBackwardsSearch)]) == host.length) {
                        isExternal = NO;
                        *stop = YES;
                    }
                }];
            }
        }
        
        // Open in external web view controller if the URL is external.
        
        if (isExternal) {
            RWebViewController *externalWebViewController = [[RWebViewController alloc] init];
            externalWebViewController.startURL = request.URL;
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:externalWebViewController];
            [self presentViewController:navigationController animated:YES completion:nil];
        }
        
        return !(isExternal | isBlocked);
    }
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (webView == self.webView) {
        BOOL success = NO;
        
        // Check authenticity.
        
        if (self.shouldCheckAuthenticity) {
            if ([[self.webView stringByEvaluatingJavaScriptFromString:self.authenticityCheckQueryJavaScript] isEqualToString:self.authenticityCheckResult]) {
                success = YES;
            }
        } else {
            success = YES;
        }
        
        // Refresh on fail.
        
        if (success) {
            [self resetFailRefreshCount];
        } else {
            [self failRefresh];
        }
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (webView == self.webView) {
        [self failRefresh];
    }
}

#pragma mark - Alert view delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView == self.failLoadAlertView) {
        switch (buttonIndex) {
            case 0: // Quit
                abort();
                break;
            case 1: // Retry
                [self resetFailRefreshCount];
                [self failRefresh];
                break;
            default:
                break;
        }
    }
}

@end