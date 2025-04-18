import SwiftUI
import SwiftData

// MARK: - Modèles de données
@Model
class Projet {
    var nom: String
    var tickets: [Ticket]
    var dateCreation: Date
    
    init(nom: String) {
        self.nom = nom
        self.tickets = []
        self.dateCreation = Date()
    }
    
    var nombreTickets: Int {
        return tickets.count
    }
}

@Model
class Ticket {
    var titre: String
    var desc: String
    var statut: Statut
    var priorite: Priorite
    var dateCreation: Date
    var instructions: [Instruction] = []
    @Relationship(inverse: \Projet.tickets) var projet: Projet?
    
    init(titre: String, desc: String, statut: Statut = .backlog, priorite: Priorite = .moyenne) {
        self.titre = titre
        self.desc = desc
        self.statut = statut
        self.priorite = priorite
        self.dateCreation = Date()
        self.instructions = []
    }
    
    var nombreInstructionsTerminees: Int {
        return instructions.filter { $0.estTerminee }.count
    }
    
    var nombreInstructions: Int {
        return instructions.count
    }
    
    var progressionInstructions: Double {
        if instructions.isEmpty {
            return 0.0
        }
        return Double(nombreInstructionsTerminees) / Double(nombreInstructions)
    }
}

@Model
class Instruction {
    var texte: String
    var estTerminee: Bool
    @Relationship(inverse: \Ticket.instructions) var ticket: Ticket?
    
    init(texte: String, estTerminee: Bool = false) {
        self.texte = texte
        self.estTerminee = estTerminee
    }
}

enum Statut: String, Codable, CaseIterable {
    case backlog = "Backlog"
    case aFaire = "À faire"
    case aTester = "À tester"
    case termine = "Terminé"
    
    var ordre: Int {
        switch self {
        case .backlog: return 0
        case .aFaire: return 1
        case .aTester: return 2
        case .termine: return 3
        }
    }
}

enum Priorite: String, Codable, CaseIterable {
    case basse = "Basse"
    case moyenne = "Moyenne"
    case haute = "Haute"
    case critique = "Critique"
    
    var couleur: Color {
        switch self {
        case .basse: return .green
        case .moyenne: return .blue
        case .haute: return .orange
        case .critique: return .red
        }
    }
}

// MARK: - Fenêtre principale de l'application
@main
struct JiraCloneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nouveau projet") {
                    NotificationCenter.default.post(name: Notification.Name("NouveauProjet"), object: nil)
                }
                .keyboardShortcut("n")
                
                Button("Nouveau ticket") {
                    NotificationCenter.default.post(name: Notification.Name("NouveauTicket"), object: nil)
                }
                .keyboardShortcut("t")
            }
        }
        .modelContainer(for: [Projet.self, Ticket.self])
    }
}

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.center() // ← Centre la fenêtre ici
            }
        }
        return NSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}


// MARK: - AppState
@Observable
class AppState {
    var projetSelectionne: Projet?
    var afficherFormNouveauProjet = false
    var afficherFormNouveauTicket = false
}

// MARK: - ContentView
struct ContentView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query private var projets: [Projet]
    @State private var appState = AppState()
    
    var body: some View {
        NavigationSplitView {
            List(selection: $appState.projetSelectionne) {
                ForEach(projets) { projet in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(projet.nom)
                                .font(.headline)
                            Text("\(projet.nombreTickets) tickets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(projet.dateCreation.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 3)
                    .tag(projet)
                }
            }
            .navigationTitle("Projets")
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        appState.afficherFormNouveauProjet = true
                    }) {
                        Label("Nouveau projet", systemImage: "plus")
                    }
                }
            }
            .onChange(of: appState.projetSelectionne) { oldValue, newValue in
                // Debug - affiche dans la console quand la sélection change
                print("Projet sélectionné: \(newValue?.nom ?? "aucun")")
            }
        } detail: {
            if let projet = appState.projetSelectionne {
                TableauProjetView(projet: projet, appState: appState)
                    .id(projet.id)
            } else {
                VStack {
                    Image(systemName: "square.grid.3x3.square")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.secondary)
                    Text("Sélectionnez un projet pour afficher son tableau")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Button("Créer un nouveau projet") {
                        appState.afficherFormNouveauProjet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
            }
        }
        .sheet(isPresented: $appState.afficherFormNouveauProjet) {
            NouveauProjetView(estAffiche: $appState.afficherFormNouveauProjet)
                .frame(width: 400, height: 250)
        }
        .sheet(isPresented: $appState.afficherFormNouveauTicket) {
            if let projet = appState.projetSelectionne {
                NouveauTicketView(estAffiche: $appState.afficherFormNouveauTicket, projet: projet)
                    .frame(width: 500, height: 600)
            }
        }
        .onAppear {
            if projets.isEmpty {
                creerExemplesDeTest()
            } else if appState.projetSelectionne == nil {
                appState.projetSelectionne = projets.first
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NouveauProjet"))) { _ in
            appState.afficherFormNouveauProjet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NouveauTicket"))) { _ in
            if appState.projetSelectionne != nil {
                appState.afficherFormNouveauTicket = true
            }
        }
    }
    
    // Fonction pour créer des données d'exemple
    private func creerExemplesDeTest() {
        let projetWeb = Projet(nom: "Site Web E-commerce")
        let projetMobile = Projet(nom: "Application Mobile")
        
        let tickets = [
            Ticket(titre: "Intégration paiement", desc: "Intégrer la passerelle de paiement Stripe", statut: .backlog, priorite: .haute),
            Ticket(titre: "Page produit", desc: "Créer la page de détail produit avec gallery", statut: .aFaire, priorite: .moyenne),
            Ticket(titre: "Optimisation SEO", desc: "Améliorer le référencement des pages principales", statut: .aTester, priorite: .basse),
            Ticket(titre: "Correction bug panier", desc: "Résoudre le problème de mise à jour des quantités", statut: .termine, priorite: .critique)
        ]
        
        // Ajouter des instructions à certains tickets
        let instructionsPaiement = [
            Instruction(texte: "Créer un compte développeur Stripe", estTerminee: true),
            Instruction(texte: "Générer les clés API", estTerminee: true),
            Instruction(texte: "Intégrer le SDK Stripe", estTerminee: false),
            Instruction(texte: "Implémenter le processus de paiement", estTerminee: false)
        ]
        
        let instructionsPageProduit = [
            Instruction(texte: "Maquetter la page", estTerminee: true),
            Instruction(texte: "Créer la galerie d'images", estTerminee: false),
            Instruction(texte: "Implémenter le sélecteur de variantes", estTerminee: false)
        ]
        
        for instruction in instructionsPaiement {
            tickets[0].instructions.append(instruction)
        }
        
        for instruction in instructionsPageProduit {
            tickets[1].instructions.append(instruction)
        }
        
        for ticket in tickets {
            projetWeb.tickets.append(ticket)
        }
        
        let ticketsMobile = [
            Ticket(titre: "Login avec Touch ID", desc: "Ajouter l'authentification biométrique", statut: .backlog, priorite: .haute),
            Ticket(titre: "Mode hors-ligne", desc: "Permettre l'utilisation sans connexion internet", statut: .aFaire, priorite: .moyenne),
            Ticket(titre: "Notifications push", desc: "Configurer les notifications pour les nouveaux messages", statut: .aTester, priorite: .moyenne)
        ]
        
        // Ajouter des instructions au ticket Login
        let instructionsLogin = [
            Instruction(texte: "Ajouter les permissions dans Info.plist", estTerminee: true),
            Instruction(texte: "Implémenter la méthode d'authentification", estTerminee: false),
            Instruction(texte: "Gérer les cas d'erreur", estTerminee: false)
        ]
        
        for instruction in instructionsLogin {
            ticketsMobile[0].instructions.append(instruction)
        }
        
        for ticket in ticketsMobile {
            projetMobile.tickets.append(ticket)
        }
        
        modelContext.insert(projetWeb)
        modelContext.insert(projetMobile)
        
        try? modelContext.save()
        
        // Sélectionner automatiquement le premier projet créé
        appState.projetSelectionne = projetWeb
    }
}

// MARK: - Vue du tableau de projet (style Kanban)
struct TableauProjetView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var draggedTicket: Ticket?
    @State private var targetStatut: Statut?
    var projet: Projet
    var appState: AppState
    @State private var afficherConfirmationSuppression = false
    
    private func getStatutIcon(_ statut: Statut) -> (String, Color) {
        switch statut {
        case .backlog:
            return ("tray.fill", .blue)
        case .aFaire:
            return ("play.circle.fill", .green)
        case .aTester:
            return ("checklist", .pink)
        case .termine:
            return ("checkmark.circle.fill", .orange)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête du projet
            HStack {
                Text(projet.nom)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    Button("Renommer le projet", action: {
                        // À implémenter
                    })
                    
                    Button("Supprimer le projet", role: .destructive) {
                        afficherConfirmationSuppression = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 50)
                
                Button(action: {
                    appState.afficherFormNouveauTicket = true
                }) {
                    Label("Nouveau ticket", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.leading)
            }
            .padding()
            .background(.ultraThinMaterial)
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 2)
            
            // Colonnes de statuts
            HStack(spacing: 16) {
                ForEach(Statut.allCases, id: \.self) { statut in
                    VStack(spacing: 0) {
                        // En-tête de colonne
                        HStack {
                            let (icon, color) = getStatutIcon(statut)
                            Image(systemName: icon)
                                .foregroundColor(color)
                                .font(.headline)
                            
                            Text(statut.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(ticketsDansColonne(statut: statut).count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        
                        // Liste de tickets
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(ticketsDansColonne(statut: statut).sorted(by: { $0.dateCreation > $1.dateCreation })) { ticket in
                                    TicketView(ticket: ticket)
                                        .onDrag {
                                            self.draggedTicket = ticket
                                            return NSItemProvider(object: "\(ticket.id)" as NSString)
                                        }
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
                            .frame(minHeight: 300)
                        }
                        .background(.ultraThinMaterial)
                        .onDrop(of: [.text], isTargeted: nil) { providers, location in
                            guard let ticket = self.draggedTicket else { return false }
                            if ticket.statut == statut { return false }
                            withAnimation {
                                ticket.statut = statut
                            }
                            try? modelContext.save()
                            return true
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .alert("Supprimer le projet ?", isPresented: $afficherConfirmationSuppression) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                for ticket in projet.tickets {
                    modelContext.delete(ticket)
                }
                modelContext.delete(projet)
                try? modelContext.save()
                appState.projetSelectionne = nil
            }
        } message: {
            Text("Vous êtes sur le point de supprimer le projet \"\(projet.nom)\" avec \(projet.tickets.count) tickets. Cette action est irréversible.")
        }
    }
    
    private func ticketsDansColonne(statut: Statut) -> [Ticket] {
        return projet.tickets.filter { $0.statut == statut }
    }
}

// MARK: - Vue d'un ticket
struct TicketDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var ticket: Ticket
    @State private var nouvelleInstruction: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // En-tête avec titre et priorité
            HStack {
                Text(ticket.titre)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Priorité", selection: $ticket.priorite) {
                    ForEach(Priorite.allCases, id: \.self) { priorite in
                        HStack {
                            Circle()
                                .fill(priorite.couleur)
                                .frame(width: 10, height: 10)
                            Text(priorite.rawValue)
                        }
                        .tag(priorite)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ticket.priorite.couleur.opacity(0.1))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Description du ticket
            Group {
                Text("Description")
                    .font(.headline)
                
                TextEditor(text: $ticket.desc)
                    .padding(10)
                    .frame(height: 100)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Divider()
            
            // Section des instructions
            Group {
                Text("Instructions")
                    .font(.headline)
                
                // Barre de progression
                if ticket.nombreInstructions > 0 {
                    HStack {
                        Text("\(ticket.nombreInstructionsTerminees)/\(ticket.nombreInstructions)")
                            .font(.caption)
                        
                        ProgressView(value: ticket.progressionInstructions)
                            .progressViewStyle(.linear)
                    }
                    .padding(.bottom, 8)
                }
                
                // Liste des instructions avec checkboxes
                VStack {
                    List {
                        ForEach(ticket.instructions) { instruction in
                            HStack {
                                Button(action: {
                                    instruction.estTerminee.toggle()
                                    try? modelContext.save()
                                }) {
                                    Image(systemName: instruction.estTerminee ? "checkmark.square.fill" : "square")
                                        .foregroundColor(instruction.estTerminee ? .green : .gray)
                                }
                                
                                TextField("Instruction", text: .init(
                                    get: { instruction.texte },
                                    set: {
                                        instruction.texte = $0
                                        try? modelContext.save()
                                    }
                                ))
                                
                                Button(action: {
                                    withAnimation {
                                        if let index = ticket.instructions.firstIndex(where: { $0.id == instruction.id }) {
                                            ticket.instructions.remove(at: index)
                                            modelContext.delete(instruction)
                                            try? modelContext.save()
                                        }
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: 200)
                    .listStyle(.plain)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Champ pour ajouter une nouvelle instruction
                    HStack {
                        TextField("Nouvelle instruction", text: $nouvelleInstruction)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        Button(action: {
                            ajouterInstruction()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .disabled(nouvelleInstruction.isEmpty)
                    }
                }
            }
            
            Divider()
            
            // Statut du ticket
            Group {
                Text("Statut")
                    .font(.headline)
                
                Picker("Statut", selection: $ticket.statut) {
                    ForEach(Statut.allCases, id: \.self) { statut in
                        Text(statut.rawValue).tag(statut)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Spacer()
            
            // Bouton pour fermer la vue détaillée
            HStack {
                Spacer()
                Button("Fermer") {
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    private func ajouterInstruction() {
        guard !nouvelleInstruction.isEmpty else { return }
        
        let instruction = Instruction(texte: nouvelleInstruction, estTerminee: false)
        ticket.instructions.append(instruction)
        try? modelContext.save()
        
        nouvelleInstruction = ""
    }
}

// 4. Modifions la vue TicketView pour ouvrir la vue détaillée
struct TicketView: View {
    @Environment(\.modelContext) private var modelContext
    @State var ticket: Ticket
    @State private var afficherDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Titre et priorité
            HStack {
                Text(ticket.titre)
                    .font(.headline)
                
                Spacer()
                
                // Badge de priorité
                HStack(spacing: 4) {
                    Circle()
                        .fill(ticket.priorite.couleur)
                        .frame(width: 8, height: 8)
                    
                    Text(ticket.priorite.rawValue)
                        .font(.caption2)
                        .foregroundColor(ticket.priorite.couleur)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(ticket.priorite.couleur.opacity(0.1))
                .cornerRadius(10)
            }
            
            // description
            if !ticket.desc.isEmpty {
                Text(ticket.desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Afficher le nombre d'instructions si présentes
            if ticket.nombreInstructions > 0 {
                HStack {
                    Image(systemName: "checklist")
                        .font(.caption2)
                    Text("\(ticket.nombreInstructionsTerminees)/\(ticket.nombreInstructions)")
                        .font(.caption2)
                    
                    // Mini-barre de progression
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 4)
                                .opacity(0.2)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .frame(width: geometry.size.width * ticket.progressionInstructions, height: 4)
                                .foregroundColor(ticket.priorite.couleur)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.top, 4)
            }
            
            // Date de création
            HStack {
                Spacer()
                Text(ticket.dateCreation.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThickMaterial)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            afficherDetails = true
        }
        .contextMenu {
            Button {
                afficherDetails = true
            } label: {
                Label("Afficher les détails", systemImage: "eye")
            }
            
            Menu {
                ForEach(Priorite.allCases, id: \.self) { priorite in
                    Button {
                        ticket.priorite = priorite
                        try? modelContext.save()
                    } label: {
                        Label(priorite.rawValue, systemImage: ticket.priorite == priorite ? "checkmark" : "")
                    }
                }
            } label: {
                Label("Changer la priorité", systemImage: "flag")
            }
            
            Divider()
            
            Button(role: .destructive) {
                if let projet = ticket.projet {
                    if let index = projet.tickets.firstIndex(where: { $0.id == ticket.id }) {
                        projet.tickets.remove(at: index)
                        try? modelContext.save()
                    }
                }
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
        .sheet(isPresented: $afficherDetails) {
            TicketDetailView(ticket: ticket)
                .frame(width: 600, height: 700)
        }
    }
}

// 5. Modifions aussi la fonction creerExemplesDeTest pour inclure des instructions
private func creerExemplesDeTest() {
    @Environment(\.modelContext) var modelContext
    let projetWeb = Projet(nom: "Site Web E-commerce")
    let projetMobile = Projet(nom: "Application Mobile")
    
    let tickets = [
        Ticket(titre: "Intégration paiement", desc: "Intégrer la passerelle de paiement Stripe", statut: .backlog, priorite: .haute),
        Ticket(titre: "Page produit", desc: "Créer la page de détail produit avec gallery", statut: .aFaire, priorite: .moyenne),
        Ticket(titre: "Optimisation SEO", desc: "Améliorer le référencement des pages principales", statut: .aTester, priorite: .basse),
        Ticket(titre: "Correction bug panier", desc: "Résoudre le problème de mise à jour des quantités", statut: .termine, priorite: .critique)
    ]
    
    // Ajouter des instructions à certains tickets
    let instructionsPaiement = [
        Instruction(texte: "Créer un compte développeur Stripe", estTerminee: true),
        Instruction(texte: "Générer les clés API", estTerminee: true),
        Instruction(texte: "Intégrer le SDK Stripe", estTerminee: false),
        Instruction(texte: "Implémenter le processus de paiement", estTerminee: false)
    ]

    let instructionsPageProduit = [
        Instruction(texte: "Maquetter la page", estTerminee: true),
        Instruction(texte: "Créer la galerie d'images", estTerminee: false),
        Instruction(texte: "Implémenter le sélecteur de variantes", estTerminee: false)
    ]
    
    for instruction in instructionsPaiement {
        tickets[0].instructions.append(instruction)
    }
    
    for instruction in instructionsPageProduit {
        tickets[1].instructions.append(instruction)
    }
    
    for ticket in tickets {
        projetWeb.tickets.append(ticket)
    }
    
    let ticketsMobile = [
        Ticket(titre: "Login avec Touch ID", desc: "Ajouter l'authentification biométrique", statut: .backlog, priorite: .haute),
        Ticket(titre: "Mode hors-ligne", desc: "Permettre l'utilisation sans connexion internet", statut: .aFaire, priorite: .moyenne),
        Ticket(titre: "Notifications push", desc: "Configurer les notifications pour les nouveaux messages", statut: .aTester, priorite: .moyenne)
    ]
    
    // Ajouter des instructions au ticket Login
    let instructionsLogin = [
        Instruction(texte: "Ajouter les permissions dans Info.plist", estTerminee: true),
        Instruction(texte: "Implémenter la méthode d'authentification", estTerminee: false),
        Instruction(texte: "Gérer les cas d'erreur", estTerminee: false)
    ]
    
    for instruction in instructionsLogin {
        ticketsMobile[0].instructions.append(instruction)
    }
    
    for ticket in ticketsMobile {
        projetMobile.tickets.append(ticket)
    }
    
    modelContext.insert(projetWeb)
    modelContext.insert(projetMobile)
}

// 6. Mettre à jour NouveauTicketView pour supporter les instructions
struct NouveauTicketView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var estAffiche: Bool
    var projet: Projet
    
    @State private var titre = ""
    @State private var desc = ""
    @State private var statut: Statut = .backlog
    @State private var priorite: Priorite = .moyenne
    @State private var nouvelleInstruction = ""
    @State private var instructions: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Nouveau ticket")
                .font(.title)
                .fontWeight(.bold)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Titre")
                        .font(.headline)
                    TextField("Titre du ticket", text: $titre)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    Text("Description")
                        .font(.headline)
                        .padding(.top, 5)
                    TextEditor(text: $desc)
                        .padding(10)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Section des instructions
                    Text("Instructions")
                        .font(.headline)
                        .padding(.top, 5)
                    
                    ForEach(instructions.indices, id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Instruction", text: $instructions[index])
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(5)
                            
                            Button(action: {
                                instructions.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Ajout d'une nouvelle instruction
                    HStack {
                        TextField("Ajouter une instruction", text: $nouvelleInstruction)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        Button(action: {
                            if !nouvelleInstruction.isEmpty {
                                instructions.append(nouvelleInstruction)
                                nouvelleInstruction = ""
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(nouvelleInstruction.isEmpty)
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Statut")
                                .font(.headline)
                            Picker("Statut", selection: $statut) {
                                ForEach(Statut.allCases, id: \.self) { statut in
                                    Text(statut.rawValue).tag(statut)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Priorité")
                                .font(.headline)
                            Picker("Priorité", selection: $priorite) {
                                ForEach(Priorite.allCases, id: \.self) { priorite in
                                    HStack {
                                        Circle()
                                            .fill(priorite.couleur)
                                            .frame(width: 8, height: 8)
                                        Text(priorite.rawValue).tag(priorite)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            
            Spacer()
            
            HStack {
                Button("Annuler") {
                    estAffiche = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Créer") {
                    creerTicket()
                    estAffiche = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(titre.isEmpty)
            }
        }
        .padding()
        .frame(minHeight: 600)
    }
    
    private func creerTicket() {
        guard !titre.isEmpty else { return }
        
        let nouveauTicket = Ticket(titre: titre, desc: desc, statut: statut, priorite: priorite)
        
        // Ajouter les instructions
        for texteInstruction in instructions {
            let instruction = Instruction(texte: texteInstruction)
            nouveauTicket.instructions.append(instruction)
        }
        
        projet.tickets.append(nouveauTicket)
        try? modelContext.save()
    }
}

// MARK: - Vue pour créer un nouveau projet
struct NouveauProjetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss // Utiliser dismiss pour fermer la vue
    @Binding var estAffiche: Bool
    @State private var nomProjet = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Nouveau projet")
                .font(.title)
                .fontWeight(.bold)
            
            Divider()
            
            TextField("Nom du projet", text: $nomProjet)
                .font(.title3)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            Spacer()
            
            HStack {
                Button("Annuler") {
                    nomProjet = "" // Réinitialiser le champ
                    estAffiche = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Créer") {
                    creerProjet()
                    nomProjet = "" // Réinitialiser le champ
                    estAffiche = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(nomProjet.isEmpty)
            }
        }
        .padding()
        .onDisappear {
            // S'assurer que le champ est réinitialisé à la fermeture
            nomProjet = ""
        }
    }
    
    private func creerProjet() {
        guard !nomProjet.isEmpty else { return }
        
        let nouveauProjet = Projet(nom: nomProjet)
        modelContext.insert(nouveauProjet)
        try? modelContext.save() // S'assurer que le projet est enregistré
    }
}

