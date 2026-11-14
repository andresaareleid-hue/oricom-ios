import UIKit
import WebKit

// Loads the live site, so every server update shows up without rebuilding the app.
let startURL = URL(string: "https://oricom.rakendus.biz/")!

// Turns the page's blob downloads (WAV / MP3 / project exports) into a native share sheet.
let downloadShim = """
(function () {
  var orig = HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click = function () {
    var a = this;
    if (a.download && a.href && a.href.indexOf('blob:') === 0) {
      fetch(a.href).then(function (r) { return r.blob(); }).then(function (b) {
        var fr = new FileReader();
        fr.onloadend = function () {
          window.webkit.messageHandlers.save.postMessage({ name: a.download, mime: b.type, data: fr.result });
        };
        fr.readAsDataURL(b);
      });
      return;
    }
    return orig.apply(this, arguments);
  };
})();
"""

class ViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    var web: WKWebView!

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let ucc = WKUserContentController()
        ucc.addUserScript(WKUserScript(source: downloadShim, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        ucc.add(self, name: "save")
        cfg.userContentController = ucc
        web = WKWebView(frame: view.bounds, configuration: cfg)
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.navigationDelegate = self
        web.allowsBackForwardNavigationGestures = true
        view.addSubview(web)
        UIApplication.shared.isIdleTimerDisabled = true
        web.load(URLRequest(url: startURL))
    }

    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "save", let d = message.body as? [String: Any],
              let dataUrl = d["data"] as? String, let comma = dataUrl.firstIndex(of: ",") else { return }
        let b64 = String(dataUrl[dataUrl.index(after: comma)...])
        guard let bytes = Data(base64Encoded: b64) else { return }
        var name = (d["name"] as? String) ?? "oricom-export"
        if name.isEmpty { name = "oricom-export" }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try bytes.write(to: url) } catch { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = view
        vc.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(vc, animated: true)
    }
}
