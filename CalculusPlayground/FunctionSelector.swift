//
//  FunctionSelector.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 18/6/26.
//


import SwiftUI
import SwiftData


struct FunctionSelector: View {
    @Query var userFunctions: [Function]
    
    @Binding var function: Function
    
    @Binding var showFunctionOptions: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .center, spacing: 10) {
                ForEach(userFunctions) { option in
                    Button {
                        function = option
                        showFunctionOptions = false
                    } label: {
                        Text(option.name)
                            .font(.title3)
                            .bold()
                            .monospaced()
                            .foregroundStyle(.primary)
                            .padding(6)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.tertiary)
                                    .frame(minWidth: 160)
                            }
                    }.tint(.purple)
                    
                }
            }.frame(minWidth: 180)
            VStack(alignment: .center, spacing: 10) {
                ForEach(Function.allFunctions) { option in
                    Button {
                        function = option
                        showFunctionOptions = false
                    } label: {
                        Text(option.name)
                            .font(.title3)
                            .bold()
                            .monospaced()
                            .foregroundStyle(.primary)
                            .padding(6)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.tertiary)
                                    .frame(minWidth: 160)
                            }
                    }.tint(.purple)
                    
                }
            }.frame(minWidth: 180)
        }
        .padding(15)
        .presentationCompactAdaptation(.popover)
    }
}

