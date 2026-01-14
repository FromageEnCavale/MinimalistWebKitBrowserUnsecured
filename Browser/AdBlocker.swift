import WebKit

enum AdBlocker {
    
    static let ruleListIdentifier = "AdBlockerRules"
    
    static func load(into config: WKWebViewConfiguration) {
        
        guard let url = Bundle.main.url(
            
            forResource: "adblocker",
            
            withExtension: "json"
            
        ) else {
            
            print("adblocker.json introuvable")
            
            return
            
        }
        
        guard let json = try? String(contentsOf: url, encoding: .utf8) else {
            
            print("Impossible de lire adblocker.json")
            
            return
            
        }
        
        WKContentRuleListStore.default().compileContentRuleList(
            
            forIdentifier: ruleListIdentifier,
            
            encodedContentRuleList: json
            
        ) { ruleList, error in
            
            if let error = error {
                
                print("Erreur compilation rules: \(error)")
                
                return
                
            }
            
            if let ruleList = ruleList {
                
                config.userContentController.add(ruleList)
                
                print("AdBlocker chargé")
                
            }
            
        }
        
    }
    
}
