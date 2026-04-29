import AppKit
import WebKit

protocol GoogleAuthDelegate: AnyObject {
    func didCompleteAuth(withCode code: String)
    func didFailAuth(withError error: Error)
}

class GoogleAuthViewController: NSViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var authURL: URL!
    weak var delegate: GoogleAuthDelegate?
    
    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 450, height: 600), configuration: webConfiguration)
        webView.navigationDelegate = self
        // Set custom user agent because Google sometimes blocks WKWebView without it
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Clear cookies before starting to ensure a fresh login
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0)) {
            let request = URLRequest(url: self.authURL)
            self.webView.load(request)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.absoluteString.starts(with: "http://127.0.0.1") {
            // Check for code
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                
                if let code = queryItems.first(where: { $0.name == "code" })?.value {
                    delegate?.didCompleteAuth(withCode: code)
                    decisionHandler(.cancel)
                    self.view.window?.close()
                    return
                } else if let error = queryItems.first(where: { $0.name == "error" })?.value {
                    delegate?.didFailAuth(withError: NSError(domain: "GoogleAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: error]))
                    decisionHandler(.cancel)
                    self.view.window?.close()
                    return
                }
            }
        }
        decisionHandler(.allow)
    }
}
