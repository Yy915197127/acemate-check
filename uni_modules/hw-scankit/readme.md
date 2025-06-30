# HW-ScanKit
### 介绍
HW-ScanKit 是一款支持iOS/Android/HarmonyOS 的二维码扫描插件，使用华为统一扫码SDK

### 使用方法
```
import { scan } from '@/uni_modules/hw-scankit'

startScan() {
	// 第一个参数是option，目前可以先传空，仅在Android上起作用
	scan(null, (res) => {
		console.log(JSON.stringify(res))
		if(res.code === 0 && res.data.scanType === "QR_CODE") {
			this.qrcodeUuid = res.data.originalValue
			this.open()
		}
	})
}
```

### 参数及结果说明：

option:Object

|     字段             | 描述                    |
|-----------------------|-------------------------|
| **titleType**    | 标题类型(仅Android):<br />0：设置扫码标题为“扫描二维码/条码”，默认为0；<br />1：设置扫码标题为“扫描二维码”。             |

ScanType: string
| 格式                  | 描述                    |
|-----------------------|-------------------------|
| **FORMAT_UNKNOWN**    | 未知格式                |
| **AZTEC_CODE**        | Aztec 二维码            |
| **CODABAR_CODE**      | Codabar 条形码          |
| **CODE39_CODE**       | Code 39 条形码          |
| **CODE93_CODE**       | Code 93 条形码          |
| **CODE128_CODE**      | Code 128 条形码         |
| **DATAMATRIX_CODE**   | DataMatrix 二维码       |
| **EAN8_CODE**         | EAN-8 条形码            |
| **EAN13_CODE**        | EAN-13 条形码           |
| **ITF14_CODE**        | ITF-14 条形码           |
| **PDF417_CODE**       | PDF417 二维码           |
| **QR_CODE**           | QR 二维码               |
| **UPC_A_CODE**        | UPC-A 条形码            |
| **UPC_E_CODE**        | UPC-E 条形码            |
| **MULTIFUNCTIONAL_CODE** | 多功能条形码         |
| **ONE_D_CODE**        | 一维条形码              |
| **TWO_D_CODE**        | 二维条形码              |

res:Object

| 字段                  | 描述                    |
|-----------------------|-------------------------|
| **code**       | 结果码：0代表识别成功，其他均为失败，透传华为统一扫描服务返回的code         |
| **msg**        | 结果描述：透传华为扫描服务返回的message，ios没有message             	|
| **data**       | Object              												|
| -**originalValue**        | 二维码内容            									|
| -**scanType**        | 扫码类型              										|

### 注意
1. 华为统一扫码sdk不支持模拟器，故本插件在模拟器下可能编译或者调用不成功，需要真机调试
2. 真机调试 HbuilderX 需要配置各平台运行环境配置
3. 真机调试Android需要自定义基座再运行，iOS和HarmonyOS 不需要。
4. android targetSDK请设置不低于33否则从相册选取图片可能无法使用