<p align="center">
<img height="256" src="https://raw.githubusercontent.com/zhiozhou/pics/master/picgo/2024-11%2FNetEaseMusicCloudMatchLogo-56ce69.png">
</p>

<h1 align="center">NetEaseMusicCloudMatch</h1>

[wuhenge/NeteaseMusicCloudMatch](https://github.com/wuhenge/NeteaseMusicCloudMatch)使用的C#开发，只支持Windows系统，所以按原逻辑编写了一套Swift版本以支持MacOS。

### 上手指南

进入[Releases页面](https://github.com/zhiozhou/NetEaseMusicCloudMatch/releases)下载最新版本并安装，打开NetEaseMusicCloudMatch

![Preview](https://raw.githubusercontent.com/zhioak/pics/master/picgo/2025-09%2FiShot_2025-09-09_16.43.44-625179.png)

点击蓝色链接跳转网易云音乐网页版，按F12打开浏览器控制台，切换到Network（网络）后，进行登录

![Preview](https://raw.githubusercontent.com/zhioak/pics/master/picgo/2025-09%2FiShot_2025-09-09_16.28.37-dbdacf.png)

登录成功后的请求都会携带登录Cookie，复制Cookie

![Preview](https://raw.githubusercontent.com/zhioak/pics/master/picgo/2025-09%2FiShot_2025-09-09_16.30.21-27ba8c.png)

将Cookie粘贴到输入框，点击`Cookie登录`

![Preview](https://raw.githubusercontent.com/zhioak/pics/master/picgo/2025-09%2FiShot_2025-09-09_16.43.54-79260a.png)

Cookie登录完成后展示云盘信息

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
- [Immask-rgb (QiYouJiang)](https://github.com/Immask-rgb)
- [zzixxxx](https://github.com/zzixxxx)