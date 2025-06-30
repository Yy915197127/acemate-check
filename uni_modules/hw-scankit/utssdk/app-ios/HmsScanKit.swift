import ScanKitFrameWork

class HmsScanKit : NSObject {
    
    let callback:([String : String?]) -> Void
	let log:(String) -> Void
    
    init(log:@escaping (String) -> Void, callback:@escaping ([String : String?]) -> Void) {
        self.callback = callback
		self.log = log
        super.init()
		self.log("init")
    }
	
	func scan(from:UIViewController){
		self.log("start")
	    let options = HmsScanOptions(scanFormatType:
	                                        UInt32(HMSScanFormatTypeCode.ALL.rawValue),
	                                         photo: false)
	    let scanVc = HmsDefaultScanViewController(defaultScanWithFormatType: options)!
	    scanVc.modalPresentationStyle = UIModalPresentationStyle.fullScreen
	    scanVc.defaultScanDelegate = self
	    from.present(scanVc, animated: true)
	}
	deinit {
		self.log("deinit")
	}
}

extension HmsScanKit : DefaultScanDelegate {
    func defaultScanDelegate(forDicResult resultDic: [AnyHashable : Any]!) {
		self.log("result")
        let scanType = resultDic["formatValue"] as? String
        let originalValue = resultDic["text"] as? String
        self.callback([
			"originalValue": originalValue,
			"scanType": scanType
		])
    }
}