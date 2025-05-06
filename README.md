<p align="center">
<img height="256" src="https://raw.githubusercontent.com/zhiozhou/pics/master/picgo/2024-11%2FNetEaseMusicCloudMatchLogo-56ce69.png">
</p>

<h1 align="center">NetEaseMusicCloudMatch</h1>

[wuhenge/NeteaseMusicCloudMatch](https://github.com/wuhenge/NeteaseMusicCloudMatch)使用的C#开发，只支持Windows系统，所以按原逻辑编写了一套Swift版本以支持MacOS。

### 在线求助

扫码登录响应报错`需要行为验证码验证`，因为是c#版的逻辑平移，我不太清楚这个要执行什么逻辑，重定向接口要带什么参数，哪位大佬知道吗

```bash
Request URL: https://music.163.com/api/login/qrcode/client/login
Request Method: POST
Request Headers: ["Content-Type": "application/x-www-form-urlencoded"]
Request Body: type=1&key=b5880215-7578-4a91-b369-cc56c630275f
Response Status Code: 200
Response Headers: [AnyHashable("Vary"): Accept-Encoding, AnyHashable("mconfig-bucket"): 999999, AnyHashable("Date"): Tue, 06 May 2025 01:52:18 GMT, AnyHashable("x-via"): MusicServer, AnyHashable("x-traceid"): 00000196a34b38e5016c0a3b18b4131d, AnyHashable("Expires"): Thu, 01 Jan 1970 00:00:00 GMT, AnyHashable("gw-thread"): 35752, AnyHashable("Content-Type"): application/json;charset=UTF-8, AnyHashable("x-traceid-v2"): 86b44b07cdd99558828ce967677552b2^1744960013638^-4771728062, AnyHashable("gw-time"): 1746496338152, AnyHashable("x-from-src"): 106.38.39.198, AnyHashable("Content-Encoding"): br, AnyHashable("Server"): nginx, AnyHashable("Cache-Control"): no-cache, no-store]
Response Data: ["redirectUrl": https://qa-yyy.igame.163.com/anquanhuanjingfengxian, "code": 8821, "message": 需要行为验证码验证]
```

### 上手指南

进入[Releases页面](https://github.com/zhiozhou/NetEaseMusicCloudMatch/releases)下载最新版本并安装，打开NetEaseMusicCloudMatch后使用网易云音乐App扫码登录

![Preview](https://raw.githubusercontent.com/zhiozhou/pics/master/picgo/2024-11%2FNetEaseMusicCloudMatch-login-c6b0ad.png)

登录完成后展示云盘信息

![Preview](https://raw.githubusercontent.com/zhiozhou/pics/master/picgo/2024-11%2FNetEaseMusicCloudMatch-step-1-a6b946.png)

选中歌曲后，输入需要匹配的歌曲ID

> [!TIP]
>
> - 进入[网易云音乐官网](https://music.163.com/)，搜索歌曲名称
> - 点击对应歌曲进入详情页面，查看网页地址，如：`https://music.163.com/#/song?id=194769`
> - 194769就是该歌曲的歌曲ID

![Preview](https://raw.githubusercontent.com/zhiozhou/pics/master/picgo/2024-11%2FNetEaseMusicCloudMatch-step-2-0a2a40.png)

歌曲ID输入完成后，进行回车，查看日志输出匹配结果

![Preview](https://raw.githubusercontent.com/zhiozhou/pics/master/picgo/2024-11%2FNetEaseMusicCloudMatch-step-3-ad85fc.png)

### License

[MIT](https://github.com/zhioak/NetEaseMusicCloudMatch/blob/main/LICENSE)

### 特别鸣谢

- [wuhenge/NeteaseMusicCloudMatch](https://github.com/wuhenge/NeteaseMusicCloudMatch)
- [weilian](https://macosicons.com/#/u/weilian)