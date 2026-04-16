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



<video controls width="600">
  <source src="https://github-production-user-asset-6210df.s3.amazonaws.com/106523216/579138982-e840449d-0a3f-44e4-bf0d-8e8b6d374dc3.mp4?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAVCODYLSA53PQK4ZA%2F20260416%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260416T095422Z&X-Amz-Expires=300&X-Amz-Signature=835c7a8d3cca2a9c6b61484446de37637a53ed4717e115745b72005b20bd7976&X-Amz-SignedHeaders=host&response-content-type=video%2Fmp4" type="video/mp4">
</video>
