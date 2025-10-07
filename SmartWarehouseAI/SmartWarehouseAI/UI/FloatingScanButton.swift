//
//  FloatingScanButton.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct FloatingScanButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Preview

struct FloatingScanButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2)
                .ignoresSafeArea()

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingScanButton {
                        print("Scan button tapped")
                    }
                    .padding()
                }
            }
        }
    }
}
