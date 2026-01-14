// MARK: - App Entry Point

import SwiftUI

import WebKit

@main

struct BrowserApp: App {
    
    @State private var showURLBar = true
    
    @State private var reloadToken = 0
    
    var body: some Scene {
        
        WindowGroup {
            
            ContentView(
            
                showURLBar: $showURLBar,
                
                reloadToken: $reloadToken
                
            )
            
        }
        
        .commands {
        
            BrowserCommands(
                
                onToggleURLBar: { showURLBar.toggle() },
                
                onReload: { reloadToken += 1 }
                
            )
            
        }
        
    }
    
}

// MARK: - Commands

struct BrowserCommands: Commands {
    
    let onToggleURLBar: () -> Void
    
    let onReload: () -> Void
    
    var body: some Commands {
        
        CommandGroup(after: .newItem) {
            
            Button("Open the URL bar") {
                
                onToggleURLBar()
                
            }
            
            .keyboardShortcut(" ", modifiers: .control)
            
            Button("Reload the page") {
                
                onReload()
                
            }
            
            .keyboardShortcut("r", modifiers: .control)
            
        }
        
    }
    
}

// MARK: - Content View

struct ContentView: View {
    
    @Binding var showURLBar: Bool
    
    @Binding var reloadToken: Int
    
    @State private var currentURL: String = ""
    
    @State private var urlInput = ""
    
    @State private var isSecure = false
    
    var body: some View {
        
        ZStack {
            
            if !currentURL.isEmpty {
                
                WebView(
                    
                    urlString: currentURL,
                    
                    currentURL: $currentURL,
                    
                    reloadToken: reloadToken
                    
                )
                
            } else {
                
                Color(nsColor: .windowBackgroundColor)
                
                    .ignoresSafeArea()
                
            }
            
            if showURLBar {
                
                URLBarOverlay(
                    
                    urlInput: $urlInput,
                    
                    currentURL: currentURL,
                    
                    isVisible: $showURLBar,
                    
                    isSecure: isSecure,
                    
                    onSubmit: loadURL
                    
                )
                
            }
            
        }
        
        .frame(minWidth: 400, minHeight: 400)
        
        .onChange(of: currentURL) { _, newURL in
            
            updateSecurityStatus(newURL)
            
        }
        
        .onChange(of: showURLBar) { _, isVisible in
            
            if isVisible {
                
                urlInput = currentURL
                
            }
            
        }
        
        .onAppear {
            
            updateSecurityStatus(currentURL)
            
        }
        
    }
    
    private func updateSecurityStatus(_ urlString: String) {
        
        guard let url = URL(string: urlString) else {
            
            isSecure = false
            
            return
            
        }
        
        isSecure = url.scheme == "https"
        
    }
    
    private func loadURL(_ input: String) {
        
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            
            showURLBar = false
            
            return
            
        }
        
        currentURL = URLResolver.resolve(trimmed)
        
        showURLBar = false
        
    }
    
}

// MARK: - URL Bar Overlay

struct URLBarOverlay: View {
    
    @Binding var urlInput: String
    
    let currentURL: String
    
    @Binding var isVisible: Bool
    
    let isSecure: Bool
    
    let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool

    private var shouldShowSearchIcon: Bool {
        
        currentURL.isEmpty || (isFocused && urlInput != currentURL)
        
    }
    
    var body: some View {
        
        VStack {
            
            HStack(spacing: 12) {
                
                Image(systemName: shouldShowSearchIcon
                      
                      ? "magnifyingglass"
                      
                      : (isSecure ? "lock.fill" : "lock.open.fill"))
                
                .foregroundColor(
                    
                    shouldShowSearchIcon
                    
                    ? .secondary
                    
                    : (isSecure ? .secondary : .orange)
                    
                )
                
                .imageScale(.medium)
                
                TextField("Entrez une URL ou recherchez...", text: $urlInput)
                
                    .textFieldStyle(.plain)
                
                    .font(.system(size: 16))
                
                    .focused($isFocused)
                
                    .onSubmit {
                        
                        onSubmit(urlInput)
                        
                    }
                
                if !urlInput.isEmpty {
                    
                    Button(action: { urlInput = "" }) {
                        
                        Image(systemName: "xmark.circle.fill")
                        
                            .foregroundColor(.secondary)
                        
                            .imageScale(.medium)
                        
                    }
                    
                    .buttonStyle(.plain)
                    
                }
                
            }
            
            .padding(.horizontal, 18)
            
            .padding(.vertical, 16)
            
            .glassEffect(in: .rect(cornerRadius: 16))
            
            .frame(maxWidth: 600)
            
            .padding(.bottom, 32)
            
        }
        
        .padding(16)
        
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        .contentShape(Rectangle())
        
        .onAppear {
            
            isFocused = true
            
        }
        
        .onTapGesture {
            
            isVisible = false
            
        }
        
        .onKeyPress(.escape) {
        
            isVisible = false
            
            return .handled

        }
        
    }
    
}

// MARK: - WebView

struct WebView: NSViewRepresentable {
    
    let urlString: String
    
    @Binding var currentURL: String
    
    let reloadToken: Int
    
    func makeNSView(context: Context) -> WKWebView {
        
        let config = WKWebViewConfiguration()
        
        config.websiteDataStore = .nonPersistent()
        
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        AdBlocker.load(into: config)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        webView.addObserver(
        
            context.coordinator,
            
            forKeyPath: "URL",
            
            options: [.new],
            
            context: nil
        
        )
        
        webView.navigationDelegate = context.coordinator
        
        webView.uiDelegate = context.coordinator
        
        context.coordinator.webView = webView
        
        return webView
        
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        
        if context.coordinator.lastReloadToken != reloadToken {
            
            context.coordinator.lastReloadToken = reloadToken
            
            webView.reload()
            
            return
            
        }
        
        guard let newURL = URL(string: urlString) else { return }
        
        let currentWebURL = webView.url?.standardized
        
        let targetURL = newURL.standardized
        
        if currentWebURL != targetURL {
            
            let request = URLRequest(url: newURL)
            
            webView.load(request)
            
        }
        
    }
    
    func makeCoordinator() -> Coordinator {
        
        Coordinator(currentURL: $currentURL)
        
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        
        @Binding var currentURL: String
        
        weak var webView: WKWebView?
        
        var lastReloadToken = 0
        
        init(currentURL: Binding<String>) {
            
            _currentURL = currentURL
            
        }
        
        private func updateCurrentURL(from webView: WKWebView) {
            
            if let url = webView.url?.absoluteString {
                
                DispatchQueue.main.async {
                    
                    self.currentURL = url
                    
                }
                
            }
            
        }
        
        func webView(
            
            _ webView: WKWebView,
            
            decidePolicyFor navigationAction: WKNavigationAction,
            
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
            
        ) {
            
            guard let url = navigationAction.request.url else {
                
                decisionHandler(.cancel)
                
                return
                
            }
            
            if url.scheme == "file" {
                
                decisionHandler(.cancel)
                
                return
                
            }
            
            if url.scheme == "http" || url.scheme == "https" {
                
                decisionHandler(.allow)
                
            } else {
                
                decisionHandler(.cancel)
                
            }
            
        }
        
        func webView(
            
            _ webView: WKWebView,
            
            didCommit navigation: WKNavigation!
            
        ) {
            
            updateCurrentURL(from: webView)
            
        }
        
        func webView(
            
            _ webView: WKWebView,
            
            didFinish navigation: WKNavigation!
            
        ) {
            
            updateCurrentURL(from: webView)
            
        }
        
        func webView(
            
            _ webView: WKWebView,
            
            didFail navigation: WKNavigation!,
            
            withError error: Error
            
        ) {
            
            print("Navigation failed: \(error.localizedDescription)")
            
        }
        
        func webView(
            
            _ webView: WKWebView,
            
            didFailProvisionalNavigation navigation: WKNavigation!,
            
            withError error: Error
            
        ) {
            
            print(
                
                "Provisional navigation failed: \(error.localizedDescription)"
                
            )
            
        }
        
        func webView(
            
            _ webView: WKWebView,
            
            createWebViewWith configuration: WKWebViewConfiguration,
            
            for navigationAction: WKNavigationAction,
            
            windowFeatures: WKWindowFeatures
            
        ) -> WKWebView? {
            
            if let url = navigationAction.request.url {
                
                if url.scheme == "http" || url.scheme == "https" {
                    
                    webView.load(URLRequest(url: url))
                    
                }
                
            }
            
            return nil
            
        }
        
        override func observeValue(

            forKeyPath keyPath: String?,

            of object: Any?,

            change: [NSKeyValueChangeKey : Any]?,

            context: UnsafeMutableRawPointer?

        ) {
            
            guard keyPath == "URL",
                  
                    let webView = object as? WKWebView,
                  
                    let url = webView.url?.absoluteString
                    
            else { return }
            
            DispatchQueue.main.async {
                
                if self.currentURL != url {
                    
                    self.currentURL = url
                    
                }
                
            }
            
        }
        
    }
    
    static func dismantleNSView(
    
        _ nsView: WKWebView,
        
        coordinator: Coordinator
    
    ) {
        
        nsView.removeObserver(coordinator, forKeyPath: "URL")
        
    }
    
}

// MARK: - URL Resolver

struct URLResolver {
    
    static func resolve(_ input: String) -> String {
        
        if let url = URL(string: input),
           
            let scheme = url.scheme,
           
            ["http", "https"].contains(scheme) {
            
            return input
            
        }
        
        if isDomain(input) {
            
            return "https://\(input)"
        }
        
        return searchURL(for: input)
        
    }
    
    private static func isDomain(_ input: String) -> Bool {
        
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmed.contains(" "), trimmed.contains(".") else {
            
            return false
            
        }
        
        var components = URLComponents()
        
        components.scheme = "https"
        
        components.host = trimmed
        
        guard let host = components.url?.host else { return false }
        
        let parts = host.split(separator: ".")
        
        return parts.count >= 2 && parts.last!.count >= 2
        
    }
    
    private static func searchURL(for query: String) -> String {
        
        guard let encoded = query.addingPercentEncoding(
            
            withAllowedCharacters: .urlQueryAllowed
            
        ) else {
            
            return "https://duckduckgo.com"
            
        }
        
        return "https://duckduckgo.com/?q=\(encoded)"
        
    }
    
}

