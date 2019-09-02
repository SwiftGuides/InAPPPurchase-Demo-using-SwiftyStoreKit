//
//  ViewController.swift
//  inAppPurchaseSwiftyDemo
//
//  Created by MacMini on 8/30/19.
//  Copyright © 2019 Immanent. All rights reserved.
//

import UIKit
import SwiftyStoreKit
import StoreKit

var sharedSecret = "enterSharedsectredKey"

enum RegisteredPurchase : String {
    case Dolla10 = "10Dolla"
    case RemoveAds = "RemoveAds"
    case autoRenewable = "myAutoRenewSubscription"
}



class NetworkActivityIndicatorManager : NSObject {
    
    private static var loadingCount = 0
    
    class func NetworkOperationStarted() {
        if loadingCount == 0 {
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
        loadingCount += 1
    }
    class func networkOperationFinished(){
        if loadingCount > 0 {
            loadingCount -= 1
            
        }
        
        if loadingCount == 0 {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            
        }
    }
}

class IAPSwiftyStore: UIViewController {
    
    //Call it anywhere in class like  "IAPSwiftyStore.shared.verifySubscription()"
    static let shared = IAPSwiftyStore()
    
    let bundleID = "com.inAPPPurcahseDemo"
    
    var Dolla10 = RegisteredPurchase.Dolla10
    var RemoveAds = RegisteredPurchase.RemoveAds
    var MyAutoRenewable = RegisteredPurchase.autoRenewable
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func Consumable1(_ sender: Any) {
        purchase(purchase: Dolla10)
    }
    
    @IBAction func verifyPurchase(_ sender: Any) {
        verifyPurcahse(product : MyAutoRenewable)
    }
    
    @IBAction func Renewable(_ sender: Any) {
        purchase(purchase: MyAutoRenewable)
    }
    
    @IBAction func NonRenewable(_ sender: Any) {
    }
    
    
    //MARK: Get Info For Purchase Product
    func getInfo(purchase : RegisteredPurchase) {
        NetworkActivityIndicatorManager.NetworkOperationStarted()
      
        SwiftyStoreKit.retrieveProductsInfo([bundleID + "." + purchase.rawValue], completion: {
            result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            self.showAlert(alert: self.alertForProductRetrievalInfo(result: result))
            
            
        })
    }
    
    //MARK: Make Purchase
    func purchase(purchase : RegisteredPurchase) {
        NetworkActivityIndicatorManager.NetworkOperationStarted()
        SwiftyStoreKit.purchaseProduct(bundleID + "." + purchase.rawValue, quantity: 1, atomically: true) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            switch result {
            case .success(let purchase):
                print("Purchase Success: \(purchase.productId)")
                if purchase.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                }
                self.showAlert(alert: self.alertForPurchaseResult(result: result))
            case .error(let error):
                switch error.code {
                case .unknown: print("Unknown error. Please contact support")
                case .clientInvalid: print("Not allowed to make the payment")
                case .paymentCancelled: break
                case .paymentInvalid: print("The purchase identifier was invalid")
                case .paymentNotAllowed: print("The device is not allowed to make the payment")
                case .storeProductNotAvailable: print("The product is not available in the current storefront")
                case .cloudServicePermissionDenied: print("Access to cloud service information is not allowed")
                case .cloudServiceNetworkConnectionFailed: print("Could not connect to the network")
                case .cloudServiceRevoked: print("User has revoked permission to use this cloud service")
                default: print((error as NSError).localizedDescription)
                }
            }
        }

    }
    
    //MARK: Restore Purchases
    func restorePurchases() {
        NetworkActivityIndicatorManager.NetworkOperationStarted()
        
        
        SwiftyStoreKit.restorePurchases(atomically: true, completion: {
            result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            for product in result.restoredPurchases {
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }
            self.showAlert(alert: self.alertForRestorePurchases(result: result))
        })
        
    }
    
    //MARK: Refresh/update Reciept
    func fetchUpdatedReciept(){
        SwiftyStoreKit.fetchReceipt(forceRefresh: true) { result in
            switch result {
            case .success(let receiptData):
                let encryptedReceipt = receiptData.base64EncodedString(options: [])
                print("Fetch receipt success:\n\(encryptedReceipt)")
            case .error(let error):
                print("Fetch receipt failed: \(error)")
            }
        }
    }
    
    //MARK: Verify Reciept
    func verifyReceipt() {
        NetworkActivityIndicatorManager.NetworkOperationStarted()
        
        let appleValidator = AppleReceiptValidator(service: .sandbox, sharedSecret: sharedSecret)
        SwiftyStoreKit.verifyReceipt(using: appleValidator, forceRefresh: false) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            self.showAlert(alert: self.alertForVerifyReceipt(result: result))
            switch result {
            case .success(let receipt):
                print("Verify receipt success: \(receipt)")
            case .error(let error):
                print("Verify receipt failed: \(error)")
                self.fetchUpdatedReciept()
            }
        }
    }
    
    
    //MARK: Verify Subscription/Purchase
    func verifyPurcahse(product : RegisteredPurchase) {
        NetworkActivityIndicatorManager.NetworkOperationStarted()
        
        let appleValidator = AppleReceiptValidator(service: .sandbox, sharedSecret: sharedSecret)
        SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            switch result {
            case .success(let receipt):
                let productId = self.bundleID + "." + product.rawValue
               
                // Verify the purchase of a Subscription
                let purchaseResult = SwiftyStoreKit.verifySubscription(
                    ofType: .autoRenewable, // or .nonRenewing (see below)
                    productId: productId,
                    inReceipt: receipt)
                self.showAlert(alert: self.alertForVerifySubscription(result: purchaseResult))
               // SwiftyStoreKit.verifySubscription(ofType: <#T##SubscriptionType#>, productId: <#T##String#>, inReceipt: <#T##ReceiptInfo#>, validUntil: <#T##Date#>)
                
                switch purchaseResult {
                case .purchased(let expiryDate, let items):
                    print("\(productId) is valid until \(expiryDate)\n\(items)\n")
                case .expired(let expiryDate, let items):
                    print("\(productId) is expired since \(expiryDate)\n\(items)\n")
                case .notPurchased:
                    print("The user has never purchased \(productId)")
                }
                
            case .error(let error):
                print("Receipt verification failed: \(error)")
                self.fetchUpdatedReciept()
            }
        }
        

        
    }
    
}


//MARK: Alerts Extensions
extension IAPSwiftyStore {
    
    func alertWithTitle(title : String, message : String) -> UIAlertController {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        return alert
        
    }
    func showAlert(alert : UIAlertController) {
        guard let _ = self.presentedViewController else {
            self.present(alert, animated: true, completion: nil)
            return
        }
        
    }
    func alertForProductRetrievalInfo(result : RetrieveResults) -> UIAlertController {
        if let product = result.retrievedProducts.first {
            let priceString = product.localizedPrice!
            return alertWithTitle(title: product.localizedTitle, message: "\(product.localizedDescription) - \(priceString)")
            
        }
        else if let invalidProductID = result.invalidProductIDs.first {
            return alertWithTitle(title: "Could not retreive product info", message: "Invalid product identifier: \(invalidProductID)")
        }
        else {
            let errorString = result.error?.localizedDescription ?? "Unknown Error. Please Contact Support"
            return alertWithTitle(title: "Could not retreive product info" , message: errorString)
            
        }
        
    }
    func alertForPurchaseResult(result : PurchaseResult) -> UIAlertController {
        switch result {
        case .success(let product):
            print("Purchase Succesful: \(product.productId)")
            
            return alertWithTitle(title: "Thank You", message: "Purchase completed")
        case .error(let error):
            print("Purchase Failed: \(error)")
            switch error.code {
            case .cloudServiceNetworkConnectionFailed:
                if (error as NSError).domain == SKErrorDomain {
                    return alertWithTitle(title: "Purchase Failed", message: "Check your internet connection or try again later.")
                }
                else {
                    return alertWithTitle(title: "Purchase Failed", message: "Unknown Error. Please Contact Support")
                }
            case .invalidOfferIdentifier:
                return alertWithTitle(title: "Purchase Failed", message: "this is not a valid product identifier")
            case .storeProductNotAvailable:
                return alertWithTitle(title: "Purchase Failed", message: "Product not found")
            case .paymentNotAllowed:
                return alertWithTitle(title: "Purchase Failed", message: "You are not allowed to make payments")
                
            default:
                return alertWithTitle(title: "Purchase failed", message: "Unknown error")
            }
        }
    }
    
    func alertForRestorePurchases(result : RestoreResults) -> UIAlertController {
        if result.restoreFailedPurchases.count > 0 {
            print("Restore Failed: \(result.restoreFailedPurchases)")
            return alertWithTitle(title: "Restore Failed", message: "Unknown Error. Please Contact Support")
        }
        else if result.restoredPurchases.count > 0 {
            return alertWithTitle(title: "Purchases Restored", message: "All purchases have been restored.")
            
        }
        else {
            return alertWithTitle(title: "Nothing To Restore", message: "No previous purchases were made.")
        }
        
    }
    func alertForVerifyReceipt(result: VerifyReceiptResult) -> UIAlertController {
        
        switch result {
        case.success(let receipt):
            return alertWithTitle(title: "Receipt Verified", message: "Receipt Verified Remotely")
        case .error(let error):
            switch error {
            case .noReceiptData:
                return alertWithTitle(title: "Receipt Verification", message: "No receipt data found, application will try to get a new one. Try Again.")
            default:
                return alertWithTitle(title: "Receipt verification", message: "Receipt Verification failed")
            }
        }
    }
    func alertForVerifySubscription(result: VerifySubscriptionResult) -> UIAlertController {
        switch result {
        case .purchased(let expiryDate):
            return alertWithTitle(title: "Product is Purchased", message: "Product is valid until \(expiryDate)")
        case .notPurchased:
            return alertWithTitle(title: "Not purchased", message: "This product has never been purchased")
        case .expired(let expiryDate):
            
            return alertWithTitle(title: "Product Expired", message: "Product is expired since \(expiryDate)")
        }
    }
    func alertForVerifyPurchase(result : VerifyPurchaseResult) -> UIAlertController {
        switch result {
        case .purchased:
            return alertWithTitle(title: "Product is Purchased", message: "Product will not expire")
        case .notPurchased:
            
            return alertWithTitle(title: "Product not purchased", message: "Product has never been purchased")

        }
        
    }
    
}
