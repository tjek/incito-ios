import UIKit
import WebKit
import PlaygroundSupport
import SVGKit
import Incito

PlaygroundPage.current.needsIndefiniteExecution = true

//class SVGImageRenderer: NSObject {
//    var webView: WKWebView? = nil
//
//    func render(svgStr: String) -> Future<UIImage?> {
//
//    }
//}
extension UIView {
    func snapshotAnImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.isOpaque, 0.0)
        defer { UIGraphicsEndImageContext() }
        if let context = UIGraphicsGetCurrentContext() {
            self.layer.render(in: context)
            return UIGraphicsGetImageFromCurrentImageContext()
        }
        return nil
    }
}

class SVGRendererWebKitDelegate: NSObject, WKNavigationDelegate, UIWebViewDelegate {
    
    let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isOpaque = false

        webView.takeSnapshot(with: nil) { (image, error) in
            self.completion(image)
        }
    }
    
//    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        return;
//        webView.backgroundColor = .clear
//        webView.scrollView.backgroundColor = .clear
//        webView.isOpaque = false
//        webView.scrollView.isOpaque = false
//        let snap = webView.snapshotAnImage()
//        print("load snapImg", snap)
////        if #available(iOS 11.0, *) {
////
////            webView.backgroundColor = .clear
////            webView.scrollView.backgroundColor = .clear
////            webView.isOpaque = false
////
////            print("WebView Loaded")
////            webView.takeSnapshot(with: nil) { (image, error) in
////                self.completion(image)
////            }
////        } else {
////            self.completion(nil)
////        }
//    }
}

func newSVGRender(svgData: Data, url: URL?, containerSize: CGSize, webView: WKWebView?) -> UIImage? {
    
    let start = Date.timeIntervalSinceReferenceDate
    
    guard let svgStr = String(data: svgData, encoding: .utf8) else {
        return nil
    }
    
    let grp = DispatchGroup()
    grp.enter()
    var image: UIImage? = nil
    let delegate = SVGRendererWebKitDelegate { imageSnap in
        image = imageSnap
        grp.leave()
    }
    
    DispatchQueue.main.async {
//        let config = WKWebViewConfiguration()
//        config.preferences.javaScriptEnabled = false
//        config.suppressesIncrementalRendering = true
        webView?.navigationDelegate = delegate
        webView?.frame = CGRect(origin: .zero, size: containerSize)
        
        let htmlStr = "<div style='position: absolute;top: 0px;left: 0px;width: 100vw;height: 100vh;'>\(svgStr)</div>"
        webView?.loadHTMLString(htmlStr, baseURL: url)
    }
    
    grp.wait(wallTimeout: .now() + 10)
    
    return image
}

func SVGKitRender(svgData: Data, containerSize: CGSize) -> UIImage? {
    guard let svgImage = SVGKImage(data: svgData) else {
        return nil
    }
    
    if svgImage.hasSize(),
        containerSize.width != 0, containerSize.height != 0 {
        let currentSize = svgImage.size
        // scale to fit in container
        let scaleFactor = max(currentSize.width / containerSize.width,
                              currentSize.height / containerSize.height)
        let newSize = CGSize(width: currentSize.width / scaleFactor,
                             height: currentSize.height / scaleFactor)
        svgImage.size = newSize
    }
    
    let image = SVGKExporterUIImage.export(asUIImage: svgImage)
    
    return image
}

//guard let svgData = res.value?.data else { return }
////2.126984127
//
//self.webView.loadHTMLString(htmlStr, baseURL: nil)

let irmaData = """
<svg id="Lag_1" data-name="Lag 1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 325.74 93.76"><defs><style>.cls-1{fill:#002e5e;stroke:#002e5e;stroke-linecap:square;stroke-miterlimit:2;stroke-width:2px;}</style></defs><title>Irma_logo_blue</title><path class="cls-1" d="M31.7,3l-.09,91.38H2.72V3Z" transform="translate(-1.72 -2)"/><path class="cls-1" d="M77.94,23.4l0,5.39a49,49,0,0,1,29.26-5.67,12,12,0,0,1,8,6,21.87,21.87,0,0,1,1.37,8.74l-.09,18.23H91.05l0-16.32a7.47,7.47,0,0,0-5.24-4.71c-3.16-.59-5.56,1.12-7.17,3.58L78,40.61V94.4l-28.25,0v-71Z" transform="translate(-1.72 -2)"/><path class="cls-1" d="M154,23.37l0,5c8.29-3,17-5.83,26.75-5.51,5.46.59,11,1.23,14.77,5.78,10.7-4.17,24-9,35.79-3.74,5.88,3.21,7.49,9.52,6.95,16.05l0,53.39-28.8,0V40.24c-.43-2.47-3.16-4.44-5.4-5-2.79-.22-5.78.53-7.28,3.21l-.64,1.66,0,54.3-28.36,0,0-53.75A7.41,7.41,0,0,0,164.36,36a7.7,7.7,0,0,0-7.86.64,7.1,7.1,0,0,0-2.57,4.12l0,53.68H125l0-71Z" transform="translate(-1.72 -2)"/><path class="cls-1" d="M252.67,64.47c1.07-6.53,8.42-7.86,13.61-9.25l21-3.7c2.52-.58,5.57-2.19,6.26-5,.27-4.71,1.71-10.76-3.21-13.49a7.13,7.13,0,0,0-7.54.54c-4.66,2.62-2.36,8.61-3,12.68h-25c-.75-7.28.5-14.39,6.81-18.62,9.53-5.67,21.08-5.56,32.85-5.51,10.38,1,22.58,1.66,27.07,12.73a20.53,20.53,0,0,1,1.3,7.55l0,43.05a27.64,27.64,0,0,0,3.8,8.95l-28.85,0-2.05-3.67c-8.72,2-17.29,5.19-27.08,3.69-5.93-.86-12.94-2.46-15.19-9-.59-1-.32-2.46-.75-3.58ZM280.4,78.33a9.68,9.68,0,0,0,.65,2.57,7.13,7.13,0,0,0,6.68,4,6.92,6.92,0,0,0,6.16-4.76V57.94c-4.49,2-11.32,1.18-13.46,6.69Z" transform="translate(-1.72 -2)"/></svg>
""".data(using: .utf8)!
let fishData = """
<?xml version="1.0" encoding="utf-8"?>
<!-- Generator: Adobe Illustrator 22.1.0, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->
<svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px"
viewBox="0 0 93.8 44.1" style="enable-background:new 0 0 93.8 44.1;" xml:space="preserve">
<style type="text/css">
.st0{fill-rule:evenodd;clip-rule:evenodd;fill:#0EA99E;}
.st1{fill:#FFFFFF;}
.st2{fill:none;}
.st3{fill-rule:evenodd;clip-rule:evenodd;fill:#FFFFFF;}
</style>
<g>
<path class="st0" d="M4.8,43.6c-2.4,0-4.3-1.9-4.3-4.3V4.8c0-2.4,1.9-4.3,4.3-4.3H89c2.4,0,4.3,1.9,4.3,4.3v34.4
c0,2.4-1.9,4.3-4.3,4.3H4.8z"/>
<path class="st1" d="M89,1c2.1,0,3.8,1.7,3.8,3.8v34.4c0,2.1-1.7,3.8-3.8,3.8H4.8c-2.1,0-3.8-1.7-3.8-3.8V4.8C1,2.7,2.7,1,4.8,1H89
M89,0H4.8C2.2,0,0,2.2,0,4.8v34.4c0,2.7,2.2,4.8,4.8,4.8H89c2.7,0,4.8-2.2,4.8-4.8V4.8C93.8,2.2,91.7,0,89,0L89,0z"/>
</g>
<path class="st2" d="M5.3,1.1C3.1,1.1,1.3,2.9,1.3,5v34c0,2.2,1.8,3.9,3.9,3.9h83.3c2.2,0,3.9-1.8,3.9-3.9V5c0-2.2-1.8-3.9-3.9-3.9
H5.3L5.3,1.1z"/>
<g>
<g>
<path class="st1" d="M9.2,6.3c0,1.3-0.9,2-2.1,2c-1.3,0-2.1-0.7-2.1-2c0-1.2,0.9-1.9,2.1-1.9C8.5,4.3,9.2,5.3,9.2,6.3z M6.3,6.3
c0,0.5,0.2,1.1,0.8,1.1c0.6,0,0.8-0.5,0.8-1.1c0-0.5-0.2-1-0.8-1C6.4,5.2,6.3,5.8,6.3,6.3z"/>
<path class="st1" d="M9.8,8.1V4.4h2c1.2,0,1.7,0.5,1.7,1.2C13.5,6.5,13,7,11.8,7h-0.7v1.2H9.8z M11.7,6.1c0.3,0,0.5-0.1,0.5-0.4
c0-0.3-0.4-0.4-0.7-0.4h-0.4v0.8H11.7z"/>
<path class="st1" d="M14,8.1V4.4h1.8c1.3,0,2.1,0.6,2.1,1.8c0,1.4-0.9,1.9-2.2,1.9H14z M15.3,7.3h0.3c0.6,0,1-0.3,1-1
c0-0.8-0.3-1-1-1h-0.3V7.3z"/>
<path class="st1" d="M19.8,6.8v1.3h-1.3V4.4h1.9c1.4,0,1.8,0.3,1.8,1.1c0,0.4-0.2,0.8-0.7,0.9c0.4,0.1,0.7,0.2,0.7,1
c0,0.5,0,0.6,0.1,0.6v0.1H21c0-0.1-0.1-0.3-0.1-0.6c0-0.5-0.1-0.6-0.7-0.6H19.8z M19.8,6h0.5c0.4,0,0.6-0.1,0.6-0.3
c0-0.3-0.2-0.4-0.5-0.4h-0.6V6z"/>
<path class="st1" d="M25.2,7.6h-1.1l-0.2,0.5h-1.3L24,4.4h4.1v0.9h-1.7v0.5h1.4v0.9h-1.4v0.6h1.7v0.9h-3V7.6z M24.4,6.8h0.8V5.3
h-0.4L24.4,6.8z"/>
<path class="st1" d="M28.5,4.4h3.7v1H31v2.7h-1.3V5.4h-1.2V4.4z"/>
<path class="st1" d="M32.6,4.4h3.7v1h-1.2v2.7h-1.3V5.4h-1.2V4.4z"/>
<path class="st1" d="M36.9,8.1V4.4h3.3v0.9h-2v0.5h1.7v0.9h-1.7v0.6h2.1v0.9H36.9z"/>
<path class="st1" d="M40.7,4.4h3.7v1h-1.2v2.7h-1.3V5.4h-1.2V4.4z"/>
<path class="st1" d="M4.8,13.7L6.2,10h1.4l1.5,3.7H7.7l-0.2-0.5H6.2l-0.2,0.5H4.8z M6.9,11.1l-0.4,1.3h0.8L6.9,11.1z"/>
<path class="st1" d="M12.2,12l-0.1-0.8V10h1.3v3.7h-1.3l-1.5-2l0.1,0.8v1.2H9.5V10h1.3L12.2,12z"/>
<path class="st1" d="M16.4,11.1c0-0.1-0.1-0.2-0.2-0.3c-0.1,0-0.2-0.1-0.3-0.1c-0.3,0-0.4,0.1-0.4,0.2c0,0.6,2.3,0.2,2.3,1.6
c0,0.9-0.8,1.3-1.9,1.3c-1.1,0-1.8-0.6-1.8-1.2h1.3c0,0.1,0.1,0.2,0.2,0.3c0.1,0.1,0.2,0.1,0.4,0.1c0.3,0,0.6-0.1,0.6-0.3
c0-0.6-2.3-0.2-2.3-1.6c0-0.8,0.7-1.2,1.8-1.2c1.1,0,1.6,0.5,1.7,1.2H16.4z"/>
<path class="st1" d="M17.9,10h1.3l0.7,2.5l0.7-2.5h1.3l-1.4,3.7h-1.3L17.9,10z"/>
<path class="st1" d="M21.6,13.7L23,10h1.4l1.5,3.7h-1.3l-0.2-0.5H23l-0.2,0.5H21.6z M23.7,11.1l-0.4,1.3h0.8L23.7,11.1z"/>
<path class="st1" d="M27.6,12.4v1.3h-1.3V10h1.9c1.4,0,1.8,0.3,1.8,1.1c0,0.4-0.2,0.8-0.7,0.9c0.4,0.1,0.7,0.2,0.7,1
c0,0.5,0,0.6,0.1,0.6v0.1h-1.4c0-0.1-0.1-0.3-0.1-0.6c0-0.5-0.1-0.6-0.7-0.6H27.6z M27.6,11.6h0.5c0.4,0,0.6-0.1,0.6-0.3
c0-0.3-0.2-0.4-0.5-0.4h-0.6V11.6z"/>
<path class="st1" d="M30.8,13.7V10h1.3v2.8H34v0.9H30.8z"/>
<path class="st1" d="M34.5,13.7V10h1.3v3.7H34.5z"/>
<path class="st1" d="M40.6,13.7h-0.9l-0.1-0.4c-0.2,0.2-0.6,0.5-1.2,0.5c-1,0-2-0.6-2-1.9c0-1.2,0.8-2,2.1-2c1,0,1.8,0.5,1.9,1.4
h-1.3c-0.1-0.3-0.3-0.5-0.7-0.5c-0.5,0-0.8,0.4-0.8,1.1c0,0.5,0.2,1,0.9,1c0.3,0,0.6-0.2,0.7-0.4h-0.6v-0.8h1.8V13.7z"/>
<path class="st1" d="M41.1,10h3.7v1h-1.2v2.7h-1.3V11h-1.2V10z"/>
</g>
</g>
<g>
<path class="st1" d="M13,26.8l-0.2-1.1c-1.2,1.1-2.4,1.4-4,1.4c-2,0-3.8-1-3.8-3.2c0-4.8,7.6-2.6,7.6-4.6c0-0.8-0.9-0.9-1.4-0.9
c-0.6,0-1.4,0.1-1.5,1h-4c0-2.2,1.6-3.6,5.8-3.6c5,0,5.3,1.9,5.3,4.4v5c0,0.6,0,0.9,0.6,1.4v0.2H13z M12.6,22.1
c-1.4,0.7-3.2,0.3-3.2,1.7c0,0.5,0.5,0.9,1.3,0.9C12.2,24.7,12.7,23.5,12.6,22.1z"/>
<path class="st1" d="M21.8,23.5c0,0.4,0.2,0.7,0.4,1c0.3,0.2,0.6,0.3,1,0.3c0.6,0,1.3-0.2,1.3-1c0-1.7-6.5-0.3-6.5-4.5
c0-2.7,2.8-3.5,5-3.5c2.3,0,5,0.5,5.3,3.3h-3.8c0-0.3-0.2-0.6-0.4-0.8c-0.2-0.2-0.5-0.3-0.9-0.3c-0.7,0-1.2,0.2-1.2,0.7
c0,1.5,6.7,0.5,6.7,4.5c0,2.2-1.8,3.7-5.7,3.7c-2.4,0-5.1-0.7-5.3-3.6H21.8z"/>
<path class="st1" d="M37.3,20.2c0-0.5-0.2-0.8-0.4-1.1c-0.3-0.3-0.6-0.4-1.1-0.4c-1.6,0-1.8,1.6-1.8,2.9c0,1.6,0.6,2.7,1.8,2.7
c1.1,0,1.5-0.7,1.6-1.6h4.3c-0.2,1.6-0.9,2.7-2,3.4c-1.1,0.7-2.4,1-3.9,1c-3.4,0-6.1-1.9-6.1-5.5c0-3.6,2.6-5.7,6.1-5.7
c2.8,0,5.5,1.2,5.8,4.4H37.3z"/>
</g>
<g>
<g>
<path class="st1" d="M7.3,31.8c-0.1-0.2-0.2-0.7-0.8-0.7c-0.3,0-0.8,0.3-0.8,1.3c0,0.7,0.2,1.3,0.8,1.3c0.4,0,0.7-0.2,0.8-0.7H8
c-0.1,0.8-0.6,1.4-1.5,1.4c-0.9,0-1.6-0.7-1.6-2c0-1.3,0.7-2,1.6-2c1,0,1.4,0.8,1.5,1.3H7.3z"/>
<path class="st1" d="M11.1,31.2H9.3V32H11v0.7H9.3v1h1.9v0.7H8.6v-3.8h2.5V31.2z"/>
<path class="st1" d="M11.9,30.5h1.7c0.9,0,1.1,0.7,1.1,1.1c0,0.4-0.2,0.8-0.5,0.9c0.3,0.1,0.4,0.3,0.4,1c0,0.6,0,0.7,0.2,0.8v0.1
H14c0-0.2-0.1-0.4-0.1-0.8c0-0.5,0-0.7-0.6-0.7h-0.7v1.5h-0.7V30.5z M13.5,32.2c0.4,0,0.6-0.1,0.6-0.5c0-0.2-0.1-0.5-0.5-0.5h-0.9
v1H13.5z"/>
<path class="st1" d="M17,34.3h-0.7v-3.1h-1v-0.7H18v0.7h-1V34.3z"/>
<path class="st1" d="M19.2,34.3h-0.7v-3.8h0.7V34.3z"/>
<path class="st1" d="M20.7,34.3H20v-3.8h2.4v0.7h-1.7V32h1.5v0.7h-1.5V34.3z"/>
<path class="st1" d="M23.7,34.3H23v-3.8h0.7V34.3z"/>
<path class="st1" d="M26.7,31.8c-0.1-0.2-0.2-0.7-0.8-0.7c-0.3,0-0.8,0.3-0.8,1.3c0,0.7,0.2,1.3,0.8,1.3c0.4,0,0.7-0.2,0.8-0.7
h0.7c-0.1,0.8-0.6,1.4-1.5,1.4c-0.9,0-1.6-0.7-1.6-2c0-1.3,0.7-2,1.6-2c1,0,1.4,0.8,1.5,1.3H26.7z"/>
<path class="st1" d="M30.6,31.2h-1.8V32h1.7v0.7h-1.7v1h1.9v0.7h-2.6v-3.8h2.5V31.2z"/>
<path class="st1" d="M31.4,30.5h1.7c0.9,0,1.1,0.7,1.1,1.1c0,0.4-0.2,0.8-0.5,0.9c0.3,0.1,0.4,0.3,0.4,1c0,0.6,0,0.7,0.2,0.8v0.1
h-0.8c0-0.2-0.1-0.4-0.1-0.8c0-0.5,0-0.7-0.6-0.7h-0.7v1.5h-0.7V30.5z M32.9,32.2c0.4,0,0.6-0.1,0.6-0.5c0-0.2-0.1-0.5-0.5-0.5
h-0.9v1H32.9z"/>
<path class="st1" d="M37.4,31.2h-1.8V32h1.7v0.7h-1.7v1h1.9v0.7h-2.6v-3.8h2.5V31.2z"/>
<path class="st1" d="M39.7,34.3H39v-3.1h-1v-0.7h2.8v0.7h-1V34.3z"/>
</g>
</g>
<g>
<g>
<path class="st1" d="M5.8,39.7H5.1l1.3-3.2h0.8l1.2,3.2H7.6L7.4,39H6.1L5.8,39.7z M6.3,38.5h0.9l-0.4-1.3h0L6.3,38.5z"/>
<path class="st1" d="M9.5,38.7c0,0.2,0.1,0.5,0.7,0.5c0.3,0,0.7-0.1,0.7-0.4c0-0.2-0.3-0.3-0.6-0.4L10,38.3
c-0.6-0.1-1.1-0.2-1.1-0.9c0-0.4,0.2-1,1.4-1c1.1,0,1.4,0.6,1.4,1h-0.7c0-0.1-0.1-0.5-0.7-0.5c-0.3,0-0.6,0.1-0.6,0.4
c0,0.2,0.2,0.3,0.4,0.3l0.9,0.2c0.5,0.1,0.9,0.3,0.9,0.9c0,1-1.1,1-1.4,1c-1.3,0-1.5-0.7-1.5-1.1H9.5z"/>
<path class="st1" d="M14.6,37.6c-0.1-0.2-0.2-0.6-0.8-0.6c-0.4,0-0.9,0.2-0.9,1.1c0,0.6,0.3,1.1,0.9,1.1c0.4,0,0.7-0.2,0.8-0.6
h0.7c-0.1,0.7-0.6,1.2-1.5,1.2c-0.9,0-1.6-0.6-1.6-1.7c0-1.1,0.7-1.7,1.6-1.7c1.1,0,1.5,0.7,1.5,1.1H14.6z"/>
<path class="st1" d="M17.3,38.4h-1.4v-0.6h1.4V38.4z"/>
<path class="st1" d="M18.4,39.7h-0.8l1.3-3.2h0.8l1.2,3.2h-0.8L20,39h-1.3L18.4,39.7z M18.9,38.5h0.9l-0.4-1.3h0L18.9,38.5z"/>
<path class="st1" d="M24.3,39.9l-0.4-0.4c-0.3,0.2-0.7,0.2-0.9,0.2c-0.5,0-1.7-0.2-1.7-1.7c0-1.5,1.2-1.7,1.7-1.7
c0.5,0,1.7,0.2,1.7,1.7c0,0.5-0.2,0.9-0.4,1.1l0.4,0.3L24.3,39.9z M23.4,38.5l0.4,0.3c0.1-0.2,0.2-0.4,0.2-0.7
c0-0.9-0.6-1.1-1-1.1c-0.4,0-1,0.2-1,1.1s0.6,1.1,1,1.1c0.1,0,0.3,0,0.4-0.1L23,38.8L23.4,38.5z"/>
<path class="st1" d="M28.2,38.6c0,0.8-0.6,1.2-1.4,1.2c-0.3,0-0.8-0.1-1.1-0.4c-0.2-0.2-0.3-0.5-0.3-0.8v-2.1h0.8v2.1
c0,0.4,0.3,0.6,0.6,0.6c0.5,0,0.7-0.2,0.7-0.6v-2.1h0.8V38.6z"/>
<path class="st1" d="M29.4,39.7h-0.8l1.3-3.2h0.8l1.2,3.2h-0.8L31,39h-1.3L29.4,39.7z M29.9,38.5h0.9l-0.4-1.3h0L29.9,38.5z"/>
<path class="st1" d="M33.4,39.7h-0.7v-0.7h0.7V39.7z"/>
<path class="st1" d="M35.6,36.4c0.5,0,1.7,0.2,1.7,1.7c0,1.5-1.2,1.7-1.7,1.7s-1.7-0.2-1.7-1.7C33.9,36.6,35.2,36.4,35.6,36.4z
M35.6,39.2c0.4,0,1-0.2,1-1.1S36,37,35.6,37c-0.4,0-1,0.2-1,1.1S35.2,39.2,35.6,39.2z"/>
<path class="st1" d="M38,36.5h1.8c0.9,0,1.1,0.6,1.1,0.9c0,0.4-0.2,0.7-0.5,0.8c0.3,0.1,0.4,0.2,0.4,0.8c0,0.5,0,0.6,0.2,0.6v0.1
h-0.8c0-0.2-0.1-0.3-0.1-0.6c0-0.4,0-0.6-0.6-0.6h-0.8v1.3H38V36.5z M39.6,37.9c0.4,0,0.6-0.1,0.6-0.4c0-0.2-0.1-0.4-0.5-0.4h-0.9
v0.9H39.6z"/>
<path class="st1" d="M43.3,38h1.5v1.7h-0.5l-0.1-0.4c-0.2,0.2-0.5,0.5-1.1,0.5c-0.9,0-1.6-0.6-1.6-1.7c0-0.9,0.5-1.7,1.7-1.7h0
c1.1,0,1.5,0.6,1.5,1.1h-0.7c0-0.1-0.2-0.5-0.8-0.5c-0.5,0-1,0.3-1,1.1c0,0.9,0.5,1.1,1,1.1c0.2,0,0.7-0.1,0.9-0.7h-0.8V38z"/>
</g>
</g>
<g>
<path class="st1" d="M84.3,37.2h-0.9v2.3h-0.9v-2.3h-0.9v-0.6h2.7V37.2z M86.9,38.4l0.7-1.8h1.2v2.9h-0.8v-2h0l-0.8,2h-0.6l-0.8-2
h0v2h-0.8v-2.9h1.2L86.9,38.4z"/>
</g>
<path class="st3" d="M59.3,43.8h-4.8L42.4,30.9c-1.1-1.1,0.1-2.1,1.3-3.3c1.2-1.2,2.1-1.2,3.3-0.2c5.4,4.2,9.5,11.9,9.5,11.9
C57.3,26.4,62,11.7,75.9,0.2h10.8c-1.1,0.7-3.3,2.5-4,3c-19.1,14.5-20.8,31.2-22,37.6C60.5,41.9,60.2,43.1,59.3,43.8z"/>
<g>
<path class="st1" d="M84,14.3c-0.4-0.2-0.9-0.1-1.1,0.4c-0.2,0.4-0.1,1,0.3,1.2c0.4,0.2,0.9,0.1,1.1-0.4
C84.5,15.1,84.4,14.6,84,14.3z"/>
<path class="st3" d="M88.7,10.1c-0.1-0.2-0.1-0.4-0.4-0.5c-0.1,0-0.2-0.1-0.3,0c-6,0.9-11.4,4.9-13.1,10.8
c-0.3,0.9-0.5,1.8-0.6,2.7C74.1,24,74,24.9,74,25.8c0,0.8,0,1.6,0,2.4c0,0.8,0.1,1.5,0.2,2.2c0,0.8,0,1.7-0.8,2.2
c-2.8,1.7-9.8,3.2-9.6,4.1c0.2,0.8,3.1,0.6,3.7,0.6c1.5,0,3.1-0.6,4.6-0.3c0.8,0.1,1.5,0.4,2,1c0.4,0.5,1,1.9,1.9,1.5
c1.3-0.5,0.4-3.9-0.3-6c4.9-1.7,8.6-3.2,11-7.7c1.3-2.4,2.1-5.2,2.3-7.9c0.1-0.6,0.1-1.2,0.1-1.8c0-1.6,0-3.3-0.2-4.9
C88.8,10.9,88.8,10.5,88.7,10.1C88.7,10.2,88.7,10.2,88.7,10.1z M75.2,30.7c0.2-3.1,1.1-8,2.9-11.6c0.1-0.2,0.2-0.5,0.4-0.7
c0.2,0.7,0.7,1.3,1.4,1.6c1.1,0.5,2.3,0.2,3-0.7c-0.2,1.1,0.4,2.2,1.4,2.7c0.7,0.3,1.4,0.3,2,0c-0.3,0.7-0.6,1.4-0.9,2.1
c-2,3.7-5.7,7.4-9.9,9c0,0-0.1-0.4-0.1-0.4C75.1,31.7,75.2,30.7,75.2,30.7z M86.7,21c-0.6,0.2-1.3,0.2-1.9-0.1
c-1-0.5-1.6-1.5-1.5-2.6c0-0.1,0-0.1,0-0.2c0,0,0,0,0,0c0,0,0,0,0,0c0,0-0.1,0.1-0.1,0.1c-0.7,0.8-1.9,1-2.9,0.6
c-0.7-0.3-1.1-0.8-1.3-1.5c1.8-2.9,4.4-5.2,8.1-6.6c0.3-0.1,0.9-0.4,1,0.6C88.3,12.9,88,17.2,86.7,21z"/>
</g>
</svg>
""".data(using: .utf8)!


let irmaSize = CGSize(width: 320, height: 92)
let fishSize = CGSize(width: 150, height: 70.522)

let svgData = fishData
let containerSize = fishSize

let config = WKWebViewConfiguration()
config.preferences.javaScriptEnabled = false
//config.suppressesIncrementalRendering = true
let sharedWebView = WKWebView(frame: .zero, configuration: config)

DispatchQueue.global().async {
    measure("WebKit: Fish", tests: 10) {
        let image = newSVGRender(svgData: fishData, url: nil, containerSize: fishSize, webView: sharedWebView)
    }
    
    measure("WebKit: Irma", tests: 10) {
        let image = newSVGRender(svgData: irmaData, url: nil, containerSize: irmaSize, webView: sharedWebView)
    }
    
    measure("SVGKit: Fish", tests: 10) {
        let image = SVGKitRender(svgData: fishData, containerSize: fishSize)
    }
    measure("SVGKit: Irma", tests: 10) {
        let image = SVGKitRender(svgData: irmaData, containerSize: irmaSize)
    }

}
