//
//  Strings+Extensions.swift
//  CIMetalCompilerPlugin
//
//  Created by JuniperPhoton on 2025/5/26.
//
import Foundation

extension String {
    var nameWithoutExtension: String {
        guard let url = URL(string: self) else {
            fatalError("Invalid URL string: \(self)")
        }
        return url.deletingPathExtension().lastPathComponent
    }
}
