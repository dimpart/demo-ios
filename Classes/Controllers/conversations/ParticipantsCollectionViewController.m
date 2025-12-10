//
//  ParticipantsCollectionViewController.m
//  Sechat
//
//  Created by Albert Moky on 2019/3/2.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "UIImageView+Extension.h"
#import "UIStoryboardSegue+Extension.h"

#import "DIMGlobalVariable.h"

#import "ProfileTableViewController.h"
#import "ChatManageTableViewController.h"

#import "ParticipantCollectionCell.h"
#import "ParticipantsManageTableViewController.h"

#import "ParticipantsCollectionViewController.h"

@interface ParticipantsCollectionViewController () {
    
    NSMutableArray *_participants;
}

@end

@implementation ParticipantsCollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self reloadData];
}

- (void)reloadData {
    _participants = [[NSMutableArray alloc] init];
    
    if (MKMIDIsUser(_conversation.identifier)) {
        // personal conversation
        [_participants addObject:_conversation.identifier];
    } else if (MKMIDIsGroup(_conversation.identifier)) {
        // group conversation
        id<MKMGroup> group = DIMGroupWithID(_conversation.identifier);
        [_participants addObjectsFromArray:group.members];
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    if ([segue.identifier isEqualToString:@"addParticipantsSegue"]) {
        
        ParticipantsManageTableViewController *vc = [segue visibleDestinationViewController];
        vc.conversation = _conversation;
    }
    
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _participants.count + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    // Configure the cell
    NSInteger count = _participants.count;
    NSInteger row = indexPath.row;
    if (row >= count) {
        return [collectionView dequeueReusableCellWithReuseIdentifier:@"moreCell" forIndexPath:indexPath];
    }
    
    ParticipantCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"participantCollectionCell" forIndexPath:indexPath];
    cell.participant = [_participants objectAtIndex:row];
    
    return cell;
}

#pragma mark <UICollectionViewDelegate>

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger count = _participants.count;
    NSInteger row = indexPath.row;
    if (row < count) {
        ParticipantCollectionCell *cell = (ParticipantCollectionCell *)[self collectionView:collectionView cellForItemAtIndexPath:indexPath];
        ProfileTableViewController *controller = [[ProfileTableViewController alloc] init];
        controller.contact = cell.participant;
        [self.manageViewController.navigationController pushViewController:controller animated:YES];
    }
}

@end
