## 环境变量
GO111MODULE=on 
GOPROXY=https://goproxy.io 

## mod文件指令
有四种指令：module，require，exclude，replace。
* module：模块名称
* require：依赖包列表以及版本
* exclude：禁止依赖包列表（仅在当前模块为主模块时生效）
* replace：替换依赖包列表 （仅在当前模块为主模块时生效）

## go mod命令
* GOPROXY=https://goproxy.io GO111MODULE=on go mod tidy //拉取缺少的模块，移除不用的模块。
* GOPROXY=https://goproxy.io GO111MODULE=on go mod download //下载依赖包
* GOPROXY=https://goproxy.io GO111MODULE=on go mod graph //打印模块依赖图
* GOPROXY=https://goproxy.io GO111MODULE=on go mod vendor //将依赖复制到vendor下
* GOPROXY=https://goproxy.io GO111MODULE=on go mod verify //校验依赖
* GOPROXY=https://goproxy.io GO111MODULE=on go mod why //解释为什么需要依赖
* GOPROXY=https://goproxy.io GO111MODULE=on go list -m -json all //依赖详情
