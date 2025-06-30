package uts.sdk.modules.hwScankit
import android.app.ActivityManager
import android.content.Context.ACTIVITY_SERVICE
import io.dcloud.uts.UTSAndroid
import io.dcloud.uts.UTSArray
import io.dcloud.uts.console
import com.huawei.hms.ml.scan.*
import com.huawei.hms.hmsscankit.ScanUtil
import android.content.Intent
import android.os.Parcelable
import android.widget.Toast

val REQUEST_CODE_SCAN_ONE = 334;
	val scanTypes = mapOf(
	    HmsScan.FORMAT_UNKNOWN to "FORMAT_UNKNOWN",
	    HmsScan.AZTEC_SCAN_TYPE to "AZTEC_CODE",
	    HmsScan.CODABAR_SCAN_TYPE to "CODABAR_CODE",
	    HmsScan.CODE39_SCAN_TYPE to "CODE39_CODE",
	    HmsScan.CODE93_SCAN_TYPE to "CODE93_CODE",
	    HmsScan.CODE128_SCAN_TYPE to "CODE128_CODE",
	    HmsScan.DATAMATRIX_SCAN_TYPE to "DATAMATRIX_CODE",
	    HmsScan.EAN8_SCAN_TYPE to "EAN8_CODE",
	    HmsScan.EAN13_SCAN_TYPE to "EAN13_CODE",
	    HmsScan.ITF14_SCAN_TYPE to "ITF14_CODE",
	    HmsScan.PDF417_SCAN_TYPE to "PDF417_CODE",
	    HmsScan.QRCODE_SCAN_TYPE to "QR_CODE",
	    HmsScan.UPCCODE_A_SCAN_TYPE to "UPC_A_CODE",
	    HmsScan.UPCCODE_E_SCAN_TYPE to "UPC_E_CODE",
	    HmsScan.MULTI_FUNCTIONAL_SCAN_TYPE to "MULTIFUNCTIONAL_CODE",
	)
	
	fun startScan(
		titleType: Number = 0,
		callback: (UTSArray<String>) -> Unit
	) {
		val context = UTSAndroid.getUniActivity()
		var options: HmsScanAnalyzerOptions;
		options = HmsScanAnalyzerOptions.Creator()
		.setViewType(titleType as Int)
		.setErrorCheck(true)
		.create()
		ScanUtil.startScan(context!!, REQUEST_CODE_SCAN_ONE, options)
				
		fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
			// console.log("$requestCode, $resultCode")
		    if (data != null && requestCode == REQUEST_CODE_SCAN_ONE) {
		        val errorCode: Int = data.getIntExtra(ScanUtil.RESULT_CODE, ScanUtil.SUCCESS)
		        if (errorCode == ScanUtil.SUCCESS) {
					val obj = data.getParcelableExtra(ScanUtil.RESULT) as Parcelable?
		            if (obj != null) {
		                val res = obj as HmsScan
						val type = getScanTypeName(res.getScanType())						
		                callback(UTSArray("0", "success", type, res.getOriginalValue()))
		            } else {
						UTSArray("404", "unkonwn", "-1", "")	
					}
		        } else if (errorCode == ScanUtil.ERROR_NO_READ_PERMISSION) {
					callback(UTSArray(errorCode.toString(), "permission not granted", "-1", ""))
		        } else {
					callback(UTSArray(errorCode.toString(), "unkonwn error", "-1", ""))
				}
		    }
			UTSAndroid.offAppActivityResult(::handleActivityResult);
		}
		
		UTSAndroid.onAppActivityResult(::handleActivityResult);
	}
	

	fun getScanTypeName(type: Int): String {
	    return scanTypes[type] ?: "FORMAT_UNKNOWN"
	}
	
	