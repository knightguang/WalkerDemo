//
//  ViewController.m
//  WalkerDemo
//
//  Created by 光 on 16/8/20.
//  Copyright © 2016年 光. All rights reserved.
//

#import "ViewController.h"
#import <HealthKit/HealthKit.h>


@interface ViewController ()

@property (nonatomic, strong) HKHealthStore *health;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _health = [[HKHealthStore alloc] init];
    
    // 判断当前设备是否支持 HealthKit
    if ([HKHealthStore isHealthDataAvailable]) {
        NSLog(@"Yes! HealthKit is supported on the device");
    }
   
    // 类型
    // 步数
    HKQuantityType *stepType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    // 卡路里
    HKQuantityType *calorieType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    // 走了多少路
    HKQuantityType *distanceType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
    
    NSSet *set = [NSSet setWithObject:stepType];
    NSSet *calSet = [NSSet setWithObject:calorieType];
    NSSet *distanceSet = [NSSet setWithObject:distanceType];
    
    [_health requestAuthorizationToShareTypes:nil
                                    readTypes:set
                                   completion:^(BOOL success, NSError * _Nullable error) {
                                       if (success) {
                                           
                                           NSLog(@"success");
                                           
//                                           [self readStepEveryData];
                                           [self readStepTotalData];
                                       } else {
                                           
                                           NSLog(@"requestAuthorization Failed");
                                       }
    }];
    
    [_health requestAuthorizationToShareTypes:nil
                                    readTypes:calSet
                                   completion:^(BOOL success, NSError * _Nullable error) {
                                       if (success) {
                                           
                                           NSLog(@"success");
//                                           [self readCalorieData];
                                           [self readCalorieTotalData];
                                       } else {
                                           
                                           NSLog(@"requestAuthorization Failed");
                                       }
                                   }];
    
    [_health requestAuthorizationToShareTypes:nil
                                    readTypes:distanceSet
                                   completion:^(BOOL success, NSError * _Nullable error) {
                                       if (success) {
                                           
                                           NSLog(@"success");
//                                           [self readCalorieData];
                                           [self readCalorieTotalData];
                                       } else {
                                           
                                           NSLog(@"requestAuthorization Failed");
                                       }
                                   }];
}

// 读取步数信息
- (void)readStepEveryData
{
    HKSampleType *type = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    // NSSortDescriptors用来告诉healthStore怎么样将结果排序。
    NSSortDescriptor *start = [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierStartDate ascending:NO];
    NSSortDescriptor *end = [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierEndDate ascending:NO];
    
    
    // 采集查询
    /**
     @param         sampleType
     @param         predicate        过滤条件
     @param         limit            返回结果个数 HKObjectQueryNoLimit -> 不做限制
     @param         sortDescriptors   排序方式
     @param         resultsHandler    返回结果回调
     */
    HKSampleQuery *sampleQuery = [[HKSampleQuery alloc] initWithSampleType:type predicate:nil limit:HKObjectQueryNoLimit sortDescriptors:@[start,end] resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error) {
        // 返回的结果显示，每一条数据，不是总数
        // 打印查询结果
        NSLog(@"resultCount = %ld result = %@",results.count,results);
        // 把结果装换成字符串类型
        HKQuantitySample *result = results[0];
        HKQuantity *quantity = result.quantity;
        NSString *stepStr = (NSString *)quantity;
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            //查询是在多线程中进行的，如果要对UI进行刷新，要回到主线程中
            NSLog(@"最新步数：%@",stepStr);
        }];
    }];
    
    // 开始执行给定的查询
    [_health executeQuery:sampleQuery];
}

// 解析步数信息，筛选今天的总数据
- (void)readStepTotalData
{
    HKQuantityType *type = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    // 过滤条件
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *nowDate = [NSDate date];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:nowDate];
    
    // 开始日期
    NSDate *startDate = [calendar dateFromComponents:dateComponents];
    // 结束日期
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    
    HKObserverQuery *observerQuery = [[HKObserverQuery alloc]
                              initWithSampleType:type
                                       predicate:predicate
                                   updateHandler:^(HKObserverQuery * _Nonnull query, HKObserverQueryCompletionHandler  _Nonnull completionHandler, NSError * _Nullable error) {

                                       HKStatisticsQuery *sQuery = [[HKStatisticsQuery alloc] initWithQuantityType:type quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery * _Nonnull query, HKStatistics * _Nullable result, NSError * _Nullable error) {
                                           
                                           HKQuantity *quantity = result.sumQuantity;
                                           NSInteger sumStepCount = [quantity doubleValueForUnit:[HKUnit countUnit]];
                                           
                                           NSLog(@"%ld", sumStepCount);
                                           
                                           // 数据共享，存储数据
                                           NSString *stepString = [NSString stringWithFormat:@"%ld", sumStepCount];
                                           NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"capabilities->App Groups设置id"];
                                           [defaults setObject:stepString forKey:@"stepCount"];
                                           // 同步数据保存
                                           [defaults synchronize];
                                           
                                       }];
                                       
                                       // 开始执行给定的查询
                                       [_health executeQuery:sQuery];
    }];
    
    // 开始执行给定的查询
    [_health executeQuery:observerQuery];
    
}

// 读取卡路里数据
- (void)readCalorieData
{
    HKQuantityType *calorieType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierEndDate ascending:NO];
    
    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:calorieType predicate:nil limit:HKObjectQueryNoLimit sortDescriptors:@[sortDescriptor] resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error) {
            NSLog(@"calorie : %@", results);
    }];
    
    [_health executeQuery:query];
}

// 解析卡路里数据，筛选今天的数据
- (void)readCalorieTotalData
{
    HKQuantityType *calorieType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    // 过滤条件
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *nowDate = [NSDate date];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:nowDate];
    
    // 开始日期
    NSDate *startDate = [calendar dateFromComponents:dateComponents];
    // 结束日期
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    
    HKObserverQuery *observerQuery = [[HKObserverQuery alloc]
                              initWithSampleType:calorieType
                              predicate:nil
                              updateHandler:^(HKObserverQuery * _Nonnull query, HKObserverQueryCompletionHandler  _Nonnull completionHandler, NSError * _Nullable error) {
                                  
                                  HKStatisticsQuery *sQuery = [[HKStatisticsQuery alloc] initWithQuantityType:calorieType quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery * _Nonnull query, HKStatistics * _Nullable result, NSError * _Nullable error) {
                                      
                                      HKQuantity *quantity = result.sumQuantity;
                                      
                                      // 卡路里 单位是 k卡路里
                                      NSInteger sumCalorieCount = [quantity doubleValueForUnit:[HKUnit kilocalorieUnit]];
                                      
                                      NSLog(@"%ld", sumCalorieCount);
                                      
                                      // 数据共享，存储数据
                                      NSString *stepString = [NSString stringWithFormat:@"%ld", sumCalorieCount];
                                      NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"capabilities->App Groups设置id"];
                                      [defaults setObject:stepString forKey:@"calorieCount"];
                                      // 同步数据保存
                                      [defaults synchronize];
                                      
                                  }];
                                  
                                  // 开始执行给定的查询
                                  [_health executeQuery:sQuery];
                              }];
    
    // 开始执行给定的查询
    [_health executeQuery:observerQuery];

}

// 读取路程
- (void)readDistanceData
{
    HKQuantityType *distanceType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierEndDate ascending:NO];
    
    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:distanceType predicate:nil limit:HKObjectQueryNoLimit sortDescriptors:@[sortDescriptor] resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error) {
            NSLog(@"distance : %@", results);
    }];
    
    [_health executeQuery:query];
}

// 解析里程数据，筛选今天的数据
- (void)readDistanceTotalData
{
    HKQuantityType *distanceType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
    // 过滤条件
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *nowDate = [NSDate date];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:nowDate];
    
    // 开始日期
    NSDate *startDate = [calendar dateFromComponents:dateComponents];
    // 结束日期
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    
    HKObserverQuery *observerQuery = [[HKObserverQuery alloc]
                                      initWithSampleType:distanceType
                                      predicate:nil
                                      updateHandler:^(HKObserverQuery * _Nonnull query, HKObserverQueryCompletionHandler  _Nonnull completionHandler, NSError * _Nullable error) {
                                          
                                          // 解析数据
                                          HKStatisticsQuery *sQuery = [[HKStatisticsQuery alloc] initWithQuantityType:distanceType quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery * _Nonnull query, HKStatistics * _Nullable result, NSError * _Nullable error) {
                                              
                                              HKQuantity *quantity = result.sumQuantity;
                                              
                                              // 里程数 单位是 m
                                              double sumDistanceCount = [quantity doubleValueForUnit:[HKUnit meterUnit]];
                                              
                                              NSLog(@"%lf", sumDistanceCount);
                                              
                                              // 数据共享，存储数据
                                              NSString *stepString = [NSString stringWithFormat:@"%lf", sumDistanceCount];
                                              NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"capabilities->App Groups设置id"];
                                              [defaults setObject:stepString forKey:@"distanceCount"];
                                              // 同步数据保存
                                              [defaults synchronize];
                                              
                                          }];
                                          
                                          // 开始执行给定的查询
                                          [_health executeQuery:sQuery];
                                      }];
    
    // 开始执行给定的查询
    [_health executeQuery:observerQuery];
}

/*
/
 / 数据共享，获取数据，1s更新
- (void)startTimer
{
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStepCount) userInfo:nil repeats:YES];
    [timer fire];
    
}
- (void)updateStepCount
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"capabilities->App Groups设置"];
    NSString *stepCount = [defaults objectForKey:@"stepCount"];
    if (stepCount) {
        NSLog(@"%@", stepCount);
    } else {
        NSLog(@"no data");
    }
    
}
*/

/**
 *
    // Body Measurements  身体测量
    HKQuantityTypeIdentifierBodyMassIndex               身高体重指数
    HKQuantityTypeIdentifierBodyFatPercentage           体脂率
    HKQuantityTypeIdentifierHeight                      身高
    HKQuantityTypeIdentifierBodyMass                    体重
    HKQuantityTypeIdentifierLeanBodyMass                去脂体重
 
    // Fitness 健身数据
    HKQuantityTypeIdentifierStepCount                   步数
    HKQuantityTypeIdentifierDistanceWalkingRunning      步行+跑步距离
    HKQuantityTypeIdentifierDistanceCycling             骑车距离
    HKQuantityTypeIdentifierBasalEnergyBurned           静息能量
    HKQuantityTypeIdentifierActiveEnergyBurned          活动能量
    HKQuantityTypeIdentifierFlightsClimbed              已爬楼层
    HKQuantityTypeIdentifierNikeFuel                    NikeFuel
    HKQuantityTypeIdentifierAppleExerciseTime           锻炼分钟数
 
    // Vitals  主要体征
    HKQuantityTypeIdentifierHeartRate                   心率
    HKQuantityTypeIdentifierBodyTemperature             体温
    HKQuantityTypeIdentifierBloodPressureSystolic       收缩压（用来计算血压的数据）
    HKQuantityTypeIdentifierBloodPressureDiastolic      舒张压（用来计算血压的数据）
    HKQuantityTypeIdentifierRespiratoryRate             呼吸速率
    HKQuantityTypeIdentifierBasalBodyTemperature        基础体温
 
    // Results  数据结果
    HKQuantityTypeIdentifierOxygenSaturation            血氧饱和度
    HKQuantityTypeIdentifierPeripheralPerfusionIndex    末梢灌注指数
    HKQuantityTypeIdentifierBloodGlucose                血糖
    HKQuantityTypeIdentifierNumberOfTimesFallen         摔倒次数
    HKQuantityTypeIdentifierElectrodermalActivity       皮电活动
    HKQuantityTypeIdentifierInhalerUsage                吸入剂用量
    HKQuantityTypeIdentifierBloodAlcoholContent         血液酒精浓度
    HKQuantityTypeIdentifierForcedVitalCapacity         最大肺活量|用力肺活量
    HKQuantityTypeIdentifierForcedExpiratoryVolume1     第一秒用力呼气量
    HKQuantityTypeIdentifierPeakExpiratoryFlowRate      呼气流量峰值
 
    // Nutrition  营养摄入
 
 */


@end
