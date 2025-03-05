//
//  tdriverBonjourConnectivity.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 12/9/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import "tdriverBonjourConnectivity.h"
#import "CS_serviceRegistrationV2.h"
#import "CS_basicIOConnection.h"
#import "CS_basicServer.h"
#import "CS_serviceRadar.h"
#import "tdriver_bonjourServer.h"
#import "ChatSeal.h"
#import "tdriver_bonjourClient.h"

// - forward declarations.
@interface tdriverBonjourConnectivity (table) <UITableViewDataSource, UITableViewDelegate, tdriver_bonjourClientDelegate>
@end

@interface tdriverBonjourConnectivity (radar) <CS_serviceRadarDelegate>
@end

/*******************************
 tdriverBonjourConnectivity
 *******************************/
@implementation tdriverBonjourConnectivity
/*
 *  Object attributes.
 */
{
    NSString              *myService;
    NSMutableArray        *maAllServices;
    CS_serviceRadar       *radar;
    tdriver_bonjourServer *server;
    tdriver_bonjourClient *client;
}
@synthesize tvServices;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        maAllServices = [[NSMutableArray alloc] init];
        server        = nil;
        client        = nil;
        radar         = nil;
        myService     = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [tvServices release];
    tvServices = nil;
    
    [radar stopScanning];
    [radar release];
    radar = nil;
    
    [maAllServices release];
    maAllServices = nil;
    
    [myService release];
    myService = nil;
    
    [server release];
    server = nil;
    
    [client stopTests];
    [client release];
    client = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    self.tvServices.dataSource = self;
    self.tvServices.delegate   = self;
    
    radar = [[CS_serviceRadar alloc] init];
    radar.delegate = self;
    NSError *err = nil;
    if ([radar beginScanningWithError:&err]) {
        NSLog(@"NOTICE: the radar is now scanning.");
    }
    else {
        NSLog(@"ERROR: the radar cannot begin scanning.  %@", err.localizedDescription);
    }
    
    NSUUID *uuid = [[UIDevice currentDevice] identifierForVendor];
    uuid_t bytes;
    [uuid getUUIDBytes:bytes];
    NSString *hash = [ChatSeal insecureHashForData:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
    myService = [[NSString stringWithFormat:@"@%@", hash] retain];
    server    = [[tdriver_bonjourServer alloc] initWithServiceName:myService];
}

@end

/************************************
 tdriverBonjourConnectivity (table)
 ************************************/
@implementation tdriverBonjourConnectivity (table)

/*
 *  Return the number of sections.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

/*
 *  Return the number of rows.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger) [maAllServices count];
}

/*
 *  Get a particular cell.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tvc = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil] autorelease];
    if (indexPath.row < [maAllServices count]) {
        CS_service *svc = [maAllServices objectAtIndex:indexPath.row];
        tvc.textLabel.text = svc.serviceName;
        tvc.detailTextLabel.text = svc.isBluetooth ? @"Bluetooth" : @"WiFi";
        return tvc;
    }
    return nil;
}

/*
 *  When a row is selected we need to start hammering that interface.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (client) {
        return;
    }
    CS_service *svc = [maAllServices objectAtIndex:(NSUInteger) indexPath.row];
    client          = [[tdriver_bonjourClient alloc] initWithService:svc andDelegate:self];
    self.tvServices.userInteractionEnabled = NO;
    self.tvServices.alpha                  = 0.5f;
    NSLog(@"NOTICE: Beginning client testing.");
    [client runTests];
}

/*
 *  Testing has completed so we can start anew.
 */
-(void) testingCompletedWithClient:(tdriver_bonjourClient *)c
{
    self.tvServices.userInteractionEnabled = YES;
    self.tvServices.alpha = 1.0f;
    [client release];
    client = nil;
}
@end

/***********************************
 tdriverBonjourConnectivity (radar)
 ***********************************/
@implementation tdriverBonjourConnectivity (radar)
-(void) radar:(CS_serviceRadar *)radar failedWithError:(NSError *)err
{
    NSLog(@"ERROR: the radar has failed!  %@", err);
}

-(void) radar:(CS_serviceRadar *)radar serviceAdded:(CS_service *)service
{
    if ([service.serviceName isEqualToString:myService] || service.isLocal) {
        return;
    }
    [maAllServices addObject:service];
    [self.tvServices reloadData];
}

-(void) radar:(CS_serviceRadar *)radar serviceRemoved:(CS_service *)service
{
    if ([service.serviceName isEqualToString:myService] || service.isLocal) {
        return;
    }
    [maAllServices removeObject:service];
    [self.tvServices reloadData];
}
@end