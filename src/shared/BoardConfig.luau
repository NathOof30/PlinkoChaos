--!strict

export type SlotDefinition = {
	multiplier: number,
	relativeWidth: number,
	label: string,
	color: Color3,
}

export type BallTypeDefinition = {
	Name: string,
	Color: Color3,
	Material: Enum.Material,
	Density: number,
	Friction: number,
	Elasticity: number,
	FrictionWeight: number,
	ElasticityWeight: number,
	MaxBounces: number?,
	ExplosionRadius: number?,
	ExplosionForce: number?,
	Description: string,
}

local BoardConfig = {
	-- Position globale du plateau dans le monde
	CenterPosition = Vector3.new(0, 50, 0),

	-- Dimensions globales
	PlayableWidth = 52, -- Largeur à la base (au niveau des 7 bacs)
	PlayableHeight = 66, -- Hauteur totale utilisable
	InternalDepth = 1.8, -- Épaisseur intérieure (bille 1.25 studs)

	-- Spécifications de la bille standard (bille métallique blanche/grise)
	Ball = {
		Diameter = 1.25, -- Taille optimale pour la pyramide
		Density = 1.2, -- Masse métallique
		Elasticity = 0.38, -- Rebond mesuré et naturel (anti-chaos incontrôlable)
		Friction = 0.15,
		Material = Enum.Material.Metal, -- Métallique
		Color = Color3.fromRGB(225, 228, 235), -- Blanc gris métallique (acier brossé)
		BaseValue = 10, -- Valeur de base d'une bille en pièces
		DefaultSpawnOffset = 0.5, -- Légèrement décentré pour amorcer le premier choix
		MaxLifetime = 30, -- Sécurité anti-blocage (secondes)
	},

	-- Profils des types de billes spéciales (Phase 5)
	BallTypes = {
		Standard = {
			Name = "Standard",
			Color = Color3.fromRGB(225, 228, 235),
			Material = Enum.Material.Metal,
			Density = 1.0,
			Friction = 0.15,
			Elasticity = 0.45,
			FrictionWeight = 1.0,
			ElasticityWeight = 1.0,
			Description = "Bille métallique polyvalente équilibrée.",
		},
		Heavy = {
			Name = "Lourde",
			Color = Color3.fromRGB(48, 52, 60), -- Fonte sombre
			Material = Enum.Material.Metal,
			Density = 5.5, -- Très dense et imposante
			Friction = 0.25,
			Elasticity = 0.18, -- Rebond très faible
			FrictionWeight = 1.0,
			ElasticityWeight = 1.5,
			Description = "Bille en fonte ultra dense. Écarte puissamment les billes sur son passage.",
		},
		Explosive = {
			Name = "Explosive",
			Color = Color3.fromRGB(255, 80, 20), -- Orange incandescent / feu
			Material = Enum.Material.Neon,
			Density = 0.85,
			Friction = 0.20,
			Elasticity = 0.45,
			FrictionWeight = 1.0,
			ElasticityWeight = 1.0,
			MaxBounces = 5, -- Explose au 5ème rebond (sécurité augmentée)
			ExplosionRadius = 8.0, -- Rayon de répulsion
			ExplosionForce = 22.0, -- Force d'impulsion centrifuge modérée et bornée
			Description = "Déclenche une déflagration au 5ème rebond avec clignotement progressif qui repousse violemment les billes alentour.",
		},
		Spring = {
			Name = "Ressort",
			Color = Color3.fromRGB(46, 255, 120), -- Vert fluo bondissant
			Material = Enum.Material.Neon,
			Density = 0.25, -- Ultra légère
			Friction = 0.10,
			Elasticity = 0.96, -- Rebond surpuissant
			FrictionWeight = 0.8,
			ElasticityWeight = 2.0,
			Description = "Ultra légère et bondissante. Ricoche avec dynamisme sur chaque clou.",
		},
	},

	-- Économie & Sauvegarde (Phase 3)
	Economy = {
		StartingCoins = 100, -- Pécule de départ pour tout nouveau joueur
		DropCost = 10, -- Coût pour lâcher une bille standard
		DataStoreName = "PlinkoChaos_UserData_v1",
	},

	-- Système de Deck & Cooldown Physique (Phase 4)
	Deck = {
		Size = 10, -- 10 emplacements de billes
		DefaultBallType = "Standard",
	},

	-- Spécifications de la Grille en Pyramide (Planche de Galton)
	Pyramid = {
		StartPegCount = 3, -- 3 clous au sommet (Row 1)
		Rows = 12, -- 12 rangées qui s'élargissent progressivement
		VerticalSpacing = 3.8,
		HorizontalSpacing = 3.6,
		TopOpeningWidth = 8.0, -- Largeur de l'entrée au sommet
	},

	-- Spécifications des clous
	Pegs = {
		Diameter = 0.75, -- Diamètre des clous
		PhysicalProperties = {
			Density = 1.0,
			Friction = 0.15,
			Elasticity = 0.42, -- Rebond propre
			FrictionWeight = 1.0,
			ElasticityWeight = 1.0,
		},
		Color = Color3.fromRGB(240, 240, 245),
		Material = Enum.Material.Metal,
	},

	-- Encadrement (Fond, Murs, Vitre)
	Frame = {
		BackboardThickness = 2.0,
		WallThickness = 2.0,
		GlassThickness = 0.5,
		BackboardColor = Color3.fromRGB(25, 27, 36),
		WallColor = Color3.fromRGB(45, 48, 62),
		GlassTransparency = 0.82,
	},

	-- Couloir de lâcher (Chute d'entrée au sommet)
	DropChute = {
		Height = 7.0,
		Width = 4.0, -- Couloir vertical étroit pour cadrer le drop
	},

	-- Bacs récepteurs du bas
	-- Tailles relatives : x1 est 3x plus large que x10 et 2x plus large que x2
	Slots = {
		Height = 9.0,
		SeparatorThickness = 0.6,
		List = {
			{
				multiplier = 10,
				relativeWidth = 1.0, -- Étroit (Jackpot très rare)
				label = "x10",
				color = Color3.fromRGB(255, 204, 0), -- Or
			},
			{
				multiplier = 2,
				relativeWidth = 1.5, -- Moyen
				label = "x2",
				color = Color3.fromRGB(46, 204, 113), -- Émeraude
			},
			{
				multiplier = 1,
				relativeWidth = 3.0, -- Large (Résultat fréquent)
				label = "x1",
				color = Color3.fromRGB(52, 152, 219), -- Bleu
			},
			{
				multiplier = 0.5,
				relativeWidth = 2.0, -- Moyen (Centre)
				label = "x0.5",
				color = Color3.fromRGB(127, 140, 141), -- Gris / Neutre
			},
			{
				multiplier = 1,
				relativeWidth = 3.0, -- Large (Résultat fréquent)
				label = "x1",
				color = Color3.fromRGB(52, 152, 219), -- Bleu
			},
			{
				multiplier = 2,
				relativeWidth = 1.5, -- Moyen
				label = "x2",
				color = Color3.fromRGB(46, 204, 113), -- Émeraude
			},
			{
				multiplier = 10,
				relativeWidth = 1.0, -- Étroit (Jackpot très rare)
				label = "x10",
				color = Color3.fromRGB(255, 204, 0), -- Or
			},
		} :: { SlotDefinition },
	},
}

return BoardConfig
