//
//  FunctionSelector.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 18/6/26.
//


import SwiftUI; import SwiftData


struct FunctionSelector: View {
    @Binding var function: Function
    
    @Binding var showFunctionOptions: Bool
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            ForEach(Function.allFunctions) { option in
                Button {
                    function = option
                    showFunctionOptions = false
                } label: {
                    Text(Function.functionDictionary[option] ?? "67ification")
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
        }
        .padding(20)
        .frame(minWidth: 200)
        .presentationCompactAdaptation(.popover)
    }
}
