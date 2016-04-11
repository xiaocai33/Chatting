//
//  ViewController.m
//  03-简单的聊天室
//
//  Created by 小蔡 on 16/4/11.
//  Copyright © 2016年 xiaocai. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, NSStreamDelegate>{
    NSInputStream *_inputStream;
    NSOutputStream *_outputStrame;
}

@property (nonatomic, strong) NSMutableArray *msgs;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bootomConstraint;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ViewController

- (NSMutableArray *)msgs{
    if (_msgs == nil) {
        _msgs = [NSMutableArray array];
    }
    return _msgs;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 监听键盘
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keybordWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

//移除通知
- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keybordWillChange:(NSNotification *)notifi{
    // 获取窗口的高度
    CGFloat windowH = [UIScreen mainScreen].bounds.size.height;
    
    // 键盘结束的Frm
    CGRect kbEndFrm = [notifi.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // 获取键盘结束的y值
    CGFloat kbEndY = kbEndFrm.origin.y;
    
    self.bootomConstraint.constant = windowH - kbEndY;
}

/**
 *  连接服务器
 */
- (IBAction)contactServer:(id)sender {
    //1建立连接
    NSString *host = @"127.0.0.1";
    int port = 12345;
    
    //定义输入输出流
    CFReadStreamRef inputStream;
    CFWriteStreamRef outputStream;
    
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, port, &inputStream, &outputStream);
    
    // 把C语言的输入输出流转化成OC对象
    _inputStream = (__bridge NSInputStream *)(inputStream);
    _outputStrame = (__bridge NSOutputStream *)(outputStream);
    
    //成为自己的代理
    _inputStream.delegate = self;
    _outputStrame.delegate = self;
    
    // 把输入输入流添加到主运行循环
    // 不添加主运行循环 代理有可能不工作
    [_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [_outputStrame scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    // 打开输入输出流
    [_inputStream open];
    [_outputStrame open];
    
}
/**
 *  登录
 */
- (IBAction)loginBtn:(id)sender {
    // 登录
    // 发送用户名和密码
    // 在这里做的时候，只发用户名，密码就不用发送
    
    // 如果要登录，发送的数据格式为 "iam:zhangsan";
    // 如果要发送聊天消息，数据格式为 "msg:did you have dinner";
    
    //登录的指令
    NSString *loginStr = [NSString stringWithFormat:@"iam:%@",@"xiaocai"];
    //把str转为NSData
    NSData *data = [loginStr dataUsingEncoding:NSUTF8StringEncoding];
    
    [_outputStrame write:data.bytes maxLength:data.length];
}

#pragma mark - NSStreamDelegate代理方法
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    /**
     *  NSStreamEventOpenCompleted  :  输入输出流打开成功
     *  NSStreamEventHasBytesAvailable  :  有字节可读
     *  NSStreamEventHasSpaceAvailable  :  可以发送字节
     *  NSStreamEventErrorOccurred  :     连接出现错误
     *  NSStreamEventEndEncountered  :     连接结束
     */
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            NSLog(@"输入输出流打开成功");
            break;
        case NSStreamEventHasBytesAvailable:
            NSLog(@"有字节可读");
            [self readData];
            break;
        case NSStreamEventHasSpaceAvailable:
            NSLog(@"可以发送字节");
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"连接出现错误");
            break;
        case NSStreamEventEndEncountered:
            NSLog(@"连接结束");
            // 关闭输入输出流
            [_inputStream close];
            [_outputStrame close];
            
            // 从主运行循环移除
            [_inputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            [_outputStrame removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            break;
            
        default:
            break;
    }
}

#pragma mark 读了服务器返回的数据
/**
 *  读取发送的数据
 */
- (void)readData{
    //建立一个缓冲区 可以放1024个字节
    uint8_t buf[2014];
    
    // 返回实际装的字节数
    NSInteger len = [_inputStream read:buf maxLength:sizeof(buf)];
    
    // 把字节数组转化成NSData
    NSData *data = [NSData dataWithBytes:buf length:len];
    
    // 从服务器接收到的数据
    NSString *msgStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSLog(@"%@", msgStr);
    
    // 刷新表格
    [self reloadDataWithText:msgStr];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField{
     // 如果要发送聊天消息，数据格式为 "msg:did you have dinner";
    // 聊天信息
    NSString *msg = [NSString stringWithFormat:@"msg:%@", textField.text];
    
    //把Str转成NSData
    NSData *data = [msg dataUsingEncoding:NSUTF8StringEncoding];
    
    // 刷新表格
    [self reloadDataWithText:msg];
    
    // 发送数据
    [_outputStrame write:data.bytes maxLength:data.length];
    
    // 发送完数据，清空textField
    textField.text = nil;
    
    
    return YES;
}

/**
 *  刷新表格
 */
- (void)reloadDataWithText:(NSString *)text{
    
    [self.msgs addObject:text];
    
    [self.tableView reloadData];
    
    // 数据多，应该往上滚动
    NSIndexPath *lastIndex = [NSIndexPath indexPathForRow:self.msgs.count - 1 inSection:0];
    
    [self.tableView scrollToRowAtIndexPath:lastIndex atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.msgs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *ID = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ID];
    
    cell.textLabel.text = self.msgs[indexPath.row];
    
    return cell;
   
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    [self.view endEditing:YES];
}

@end
