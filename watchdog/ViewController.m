//
//  ViewController.m
//  watchdog
//
//  Created by aaron on 2017/8/16.
//  Copyright © 2017年 aaron. All rights reserved.
//

#import "ViewController.h"
#import "Watchdog.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property(nonatomic,strong) NSArray *items;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [[Watchdog sharedInstance] fps:^(float fps) {
//        NSLog(@"fps = %f",fps);
//    }];
//    
//    [[Watchdog sharedInstance] memory];
//    [[Watchdog sharedInstance] cpu];
    
    
    self.items = [[NSArray alloc] init];
    
    //1000条记录，每条记录包含一个名字和一个头像
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i< 1000; i++) {
        [array addObject:@{@"name": [self randomName], @"image": [self randomAvatar]}];
    }
    
    self.items = array;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    NSDictionary *item = self.items[indexPath.row];
    
//    //name and image
    cell.imageView.image = [UIImage imageNamed:item[@"image"]];
    cell.textLabel.text = item[@"name"];
    
//    //image shadow
    cell.imageView.layer.shadowOffset = CGSizeMake(0, 5);
    cell.imageView.layer.shadowOpacity = 1;
    cell.imageView.layer.cornerRadius = 5.0f;
    cell.imageView.layer.masksToBounds = YES;
    
    //text shadow
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.layer.shadowOffset = CGSizeMake(0, 2);
    cell.textLabel.layer.shadowOpacity = 1;
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    sleep(1);
}


- (NSString *)randomName {
    NSArray *first = @[@"Alice",@"Bob",@"Bill"];
    NSArray *last = @[@"Appleseed",@"Bandicoot",@"Caravan"];
    NSUInteger index1 = (rand()/(double)INT_MAX) * [first count];
    NSUInteger index2 = (rand()/(double)INT_MAX) * [last count];
    return [NSString stringWithFormat:@"%@ %@", first[index1], last[index2]];
}

- (NSString *)randomAvatar {
    NSArray *images = @[@"A",@"B",@"C"];
    NSUInteger index = (rand()/(double)INT_MAX) * [images count];
    return images[index];
}

- (IBAction)btnAction:(UIButton *)sender {
    [NSThread sleepForTimeInterval:2];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
