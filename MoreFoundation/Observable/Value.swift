/// Copyright (c) 2018 Nicolas Christe
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.

import Foundation

public class Value<T>: Observable<T> {

    public private(set) var value: T

    private var sourceSubscription: Disposable!

    public init(_  initialValue: T) {
        self.value = initialValue
    }

    public func bind(to observable: ObservableType<T>) {
        sourceSubscription = observable.subscribe { event in
            switch event {
            case .next(let value):
                self.value = value
                self.onNext(value)
            case .terminated:
                self.onTerminated()
            }
        }
    }

    override public func subscribe(_ observer: Observer<T>) -> Disposable {
        let result = super.subscribe(observer)
        if !terminated {
            // forward initial value to the newly registered observer
            observer.on(.next(value))
        }
        return result
    }
}

extension Value: CustomDebugStringConvertible {

    public var debugDescription: String {
        return "\(value)"
    }
}
