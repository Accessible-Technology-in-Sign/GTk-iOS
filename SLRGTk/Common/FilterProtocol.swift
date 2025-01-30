//
//  FilterProtocol.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/30/24.
//

import Foundation

// Define the FilterI protocol
protocol FilterProtocol {
    associatedtype T
    func addFilter(name: String, filter: @escaping (T) -> T)
    func removeFilter(name: String)
    func filter(value: T) -> T
    func clearCallbacks()
}

// Implement the FilterManager class
class FilterManager<T>: FilterProtocol {
    private var filters: [String: (T) -> T] = [:]

    func addFilter(name: String, filter: @escaping (T) -> T) {
        filters[name] = filter
    }

    func removeFilter(name: String) {
        filters.removeValue(forKey: name)
    }

    func filter(value: T) -> T {
        var currentValue = value
        for filter in filters.values {
            currentValue = filter(currentValue)
        }
        return currentValue
    }

    func clearCallbacks() {
        filters.removeAll()
    }
}
