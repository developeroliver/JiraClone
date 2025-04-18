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
    @Relationship(inverse: \Projet.tickets) var projet: Projet?
    
    init(titre: String, desc: String, statut: Statut = .backlog, priorite: Priorite = .moyenne) {
        self.titre = titre
        self.desc = desc
        self.statut = statut
        self.priorite = priorite
        self.dateCreation = Date()
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


// MARK: - Vue principale
@Observable
class AppState {
    var projetSelectionne: Projet?
    var afficherFormNouveauProjet = false
    var afficherFormNouveauTicket = false
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projets: [Projet]
    @State private var appState = AppState()
    
    var body: some View {
        ZStack {
            NavigationSplitView {
                // Liste des projets dans la barre latérale
                List(projets, selection: $appState.projetSelectionne) { projet in
                    NavigationLink(value: projet) {
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
            } detail: {
                if let projet = appState.projetSelectionne {
                    TableauProjetView(projet: projet, appState: appState)
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
                        .frame(width: 500, height: 400)
                }
            }
            .onAppear {
                if projets.isEmpty {
                    creerExemplesDeTest()
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
            WindowAccessor()
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
        
        for ticket in tickets {
            projetWeb.tickets.append(ticket)
        }
        
        let ticketsMobile = [
            Ticket(titre: "Login avec Touch ID", desc: "Ajouter l'authentification biométrique", statut: .backlog, priorite: .haute),
            Ticket(titre: "Mode hors-ligne", desc: "Permettre l'utilisation sans connexion internet", statut: .aFaire, priorite: .moyenne),
            Ticket(titre: "Notifications push", desc: "Configurer les notifications pour les nouveaux messages", statut: .aTester, priorite: .moyenne)
        ]
        
        for ticket in ticketsMobile {
            projetMobile.tickets.append(ticket)
        }
        
        modelContext.insert(projetWeb)
        modelContext.insert(projetMobile)
    }
}

// MARK: - Vue du tableau de projet (style Kanban)
struct TableauProjetView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var draggedTicket: Ticket?
    var projet: Projet
    var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Barre de titre du projet
            HStack {
                Text(projet.nom)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    Button("Renommer le projet", action: {
                        // To implement
                    })
                    
                    Button("Supprimer le projet", role: .destructive) {
                        modelContext.delete(projet)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                
                Button(action: {
                    appState.afficherFormNouveauTicket = true
                }) {
                    Label("Nouveau ticket", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .padding(.leading)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Colonnes du tableau
            HStack(spacing: 0) {
                ForEach(Statut.allCases, id: \.self) { statut in
                    VStack {
                        // En-tête de colonne
                        HStack {
                            Text(statut.rawValue)
                                .font(.headline)
                                .padding(.leading)
                            
                            Spacer()
                            
                            Text("\(ticketsDansColonne(statut: statut).count)")
                                .font(.caption)
                                .padding(5)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(10)
                        }
                        .padding([.horizontal, .top])
                        .background(Color.gray.opacity(0.05))
                        
                        // Liste de tickets
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(ticketsDansColonne(statut: statut)) { ticket in
                                    TicketView(ticket: ticket)
                                        .onDrag {
                                            self.draggedTicket = ticket
                                            return NSItemProvider(contentsOf: URL(string: "\(ticket.id)"))!
                                        }
                                        .padding(.horizontal)
                                }
                                .padding(.top, 10)
                            }
                        }
                        .onDrop(of: [.url], isTargeted: nil) { providers, _ in
                            if let ticket = self.draggedTicket {
                                ticket.statut = statut
                                return true
                            }
                            return false
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(5)
                }
            }
        }
    }
    
    // Fonction pour filtrer les tickets par statut
    private func ticketsDansColonne(statut: Statut) -> [Ticket] {
        return projet.tickets.filter { $0.statut == statut }
    }
}

// MARK: - Vue d'un ticket
struct TicketView: View {
    var ticket: Ticket
    
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
            
            // desc
            if !ticket.desc.isEmpty {
                Text(ticket.desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
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
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .contentShape(Rectangle()) // Pour que toute la carte soit cliquable/draggable
        .contextMenu {
            Button {
                // Afficher détails
            } label: {
                Label("Afficher les détails", systemImage: "eye")
            }
            
            Menu {
                ForEach(Priorite.allCases, id: \.self) { priorite in
                    Button {
                        ticket.priorite = priorite
                    } label: {
                        Label(priorite.rawValue, systemImage: ticket.priorite == priorite ? "checkmark" : "")
                    }
                }
            } label: {
                Label("Changer la priorité", systemImage: "flag")
            }
            
            Divider()
            
            Button(role: .destructive) {
                // Supprimer ticket
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }
}

// MARK: - Vue pour créer un nouveau projet
struct NouveauProjetView: View {
    @Environment(\.modelContext) private var modelContext
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
                    estAffiche = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Créer") {
                    creerProjet()
                    estAffiche = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(nomProjet.isEmpty)
            }
        }
        .padding()
    }
    
    private func creerProjet() {
        guard !nomProjet.isEmpty else { return }
        
        let nouveauProjet = Projet(nom: nomProjet)
        modelContext.insert(nouveauProjet)
    }
}

// MARK: - Vue pour créer un nouveau ticket
struct NouveauTicketView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var estAffiche: Bool
    var projet: Projet
    
    @State private var titre = ""
    @State private var desc = ""
    @State private var statut: Statut = .backlog
    @State private var priorite: Priorite = .moyenne
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Nouveau ticket")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Titre")
                    .font(.headline)
                TextField("Titre du ticket", text: $titre)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                
                Text("desc")
                    .font(.headline)
                    .padding(.top, 5)
                TextEditor(text: $desc)
                    .padding(10)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
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
    }
    
    private func creerTicket() {
        guard !titre.isEmpty else { return }
        
        let nouveauTicket = Ticket(titre: titre, desc: desc, statut: statut, priorite: priorite)
        projet.tickets.append(nouveauTicket)
    }
}
