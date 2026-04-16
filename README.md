# Industry_downstream 说明文档
&nbsp;&nbsp;我用workbuddy开发了一个自动搜寻微信公众号小号（原创发布<=300篇）的功能。后续继续开发产业链下游更多功能，敬请期待。
# 使用方法
- 第一步：下载 ./Scripts/find_accounts.ps1 脚本文件，并保存到本地目录，例如 D:\workbuddy\temps；

- 第二步：登录微信，找到公众号栏目，并点击公众号栏目打开右侧导航窗口；

- 第三步：打开workbuddy，输入以下提示词（可以自己定义找多少个小号，以6篇为例）：

    &nbsp;&nbsp;任务：使用D:\workbuddy\temps\find_accounts.ps1，现在找6篇原创文章数量小于等于300篇的账号，这些账号不能重名，用表格形式返回给我。

- 第四步：等待workbuddy返回执行结果，账号名称一列即为智能体搜寻到的小号，如下图所示：

<div align="center"><img src="/Results/res_findAccounts.png"></div>

<p align="center">workbuddy执行结果图</p>

<video width="640" controls>
  <source src="https://private-user-images.githubusercontent.com/106523216/579128981-cb8d703c-05d6-4792-b38a-7166befc1330.mp4?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzYzMzI0ODcsIm5iZiI6MTc3NjMzMjE4NywicGF0aCI6Ii8xMDY1MjMyMTYvNTc5MTI4OTgxLWNiOGQ3MDNjLTA1ZDYtNDc5Mi1iMzhhLTcxNjZiZWZjMTMzMC5tcDQ_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwNDE2JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDQxNlQwOTM2MjdaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0wOGVlYjZlNGNjMGFhY2E2MTVmYmFmNzc3MDI0ODdjZmJhZTA2NGE0NTIyZDRkMzRlNWFhNmY1ZjlhNzM3NjAyJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9dmlkZW8lMkZtcDQifQ.aNcTBgKMykQ97Y2ONzHSMs86TnDeAp_s3RSvouGKYgo" type="video/mp4">
</video>
