//
//  Buffer.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/30/24.
//

class DefaultFillerDefinitions<T> {
    func passThroughFiller() -> (_ internalList: inout [T], _ frame: T) -> Bool {
        return { internalList, frame in
            internalList.append(frame)
            return true
        }
    }
    func capacityFiller(capacity: Int) -> (_ internalList: inout [T], _ frame: T) -> Bool {
        return { internalList, frame in
            internalList.append(frame)
            let ret = internalList.count >= capacity
            while (internalList.count > capacity) {
                internalList.removeLast()
            }
            return ret
        }
    }
}
import Foundation

public class Buffer<T>: CallbackManager<[T]>  {
    private var internalBuffer: [T] = []
    var filler: (_ internalList: inout [T], _ frame: T) -> Bool = DefaultFillerDefinitions().capacityFiller(capacity: 60)

    public func addElement(elem: T) {
        if filler(&internalBuffer, elem) {
            triggerCallbacks()
        }
    }

    public func triggerCallbacks() {
        triggerCallbacks(with: Array(internalBuffer))
    }

    public func clear() {
        internalBuffer.removeAll()
    }

    public var size: Int {
        return internalBuffer.count
    }
}

