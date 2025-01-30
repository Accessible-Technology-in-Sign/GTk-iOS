//
//  ICallback.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/30/24.
//


import Foundation

public protocol CallbackProtocol {
    associatedtype T
    
    func addCallback(name: String, callback: @escaping (T) -> Void)
    func removeCallback(name: String)
    func triggerCallbacks(with value: T)
    func clearCallbacks()
}

public class CallbackManager<T>: NSObject, CallbackProtocol {
    public typealias T = T
    private var callbacks: [String: (T) -> Void] = [:]
    
    public func addCallback(name: String, callback: @escaping (T) -> Void) {
        callbacks[name] = callback
    }
    
    public func removeCallback(name: String) {
        callbacks.removeValue(forKey: name)
    }
    
    public func triggerCallbacks(with value: T) {
        callbacks.values.forEach { callback in
            callback(value)
        }
    }
    
    public func clearCallbacks() {
        callbacks.removeAll()
    }
}
