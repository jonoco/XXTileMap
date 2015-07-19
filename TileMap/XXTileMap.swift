
import SpriteKit

/// Tilemap for parsing JSON tile maps and producing tilelayers and objects
class XXTileMap {
	
	/// Tilemap file
	var fileName: String
	
	/// Number of tiles in width and height
	var mapSize: CGSize = CGSizeZero
	
	/// Size of individual tiles
	var tileSize: CGSize = CGSizeZero
	
	/// Map orientation style
	var orientation: Orientation?
	
	/// Layers may be of type tilelayer or objectlayer. Order of tilelayers represents z-positioning
	var tileLayers: [String:TileLayer] = [String:TileLayer]()
	var objectLayers: [String:ObjectLayer] = [String:ObjectLayer]()
	var tilesets: [Tileset] = []
	
	/// Tilemap properties
	var properties: [String : AnyObject] = [String : AnyObject]()
	
	/// Stores cached tiles
	var tilesetTextureCache: [Int : SKTexture] = [Int:SKTexture]()
	
	/// Initialize tilemap with a tilemap .json file
	init(fileName: String) {
		self.fileName = fileName
		readFile()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func readFile() {
		let file = self.fileName.stringByDeletingPathExtension
		let ext = self.fileName.pathExtension
		
		if (ext.lowercaseString != "json") {
			NSLog("Tilemap error: tilemap is invalid data type: \(ext)")
			return
		}
		
		let path = NSBundle.mainBundle().pathForResource(file, ofType: ext)
		let data = NSData(contentsOfFile: path!, options: NSDataReadingOptions.DataReadingMappedIfSafe, error: nil)
		let json = JSON(data: data!)
		
		beginParse(json)
		
	}
	
	func beginParse(json: JSON) {
		
		// Parse tilemap properties
		self.mapSize = CGSize(width: json["width"].int!, height: json["height"].int!)
		self.tileSize = CGSize(width: json["tileheight"].int!, height: json["tilewidth"].int!)
		
		let orientation: String = json["orientation"].string!
		switch orientation {
		case "orthogonal":
			self.orientation = .Orthogonal
		case "isometric":
			self.orientation = .Isometric
		default:
			NSLog("Tilemap error: invalid tilemap orientation: \(orientation)")
			return
		}
		
		// Parse layers
		let layers = json["layers"].array!
		for layer in layers as [JSON] {
			
			let type = layer["type"]
			switch type {
			case "objectgroup":
				let mapLayer = ObjectLayer()
				mapLayer.name = layer["name"].string!.lowercaseString
				mapLayer.opacity = layer["opacity"].double!
				mapLayer.visible = layer["visible"].bool!
				mapLayer.size = CGSize(width: layer["width"].double!, height: layer["height"].double!)
				mapLayer.position = CGPoint(x: layer["x"].double!, y: layer["y"].double!)
				
				// Parse through objects array
				let objects = layer["objects"].array!
				for object in objects {
					let size = CGSize(width: object["width"].double!, height: object["height"].double!)
					let position = CGPoint(x: object["x"].double!, y: object["y"].double!)
					let name = object["name"].string!
					let visible = object["visible"].bool!
					let mapObject = MapObject(size: size, name: name, visible: visible, position: position)
					mapLayer.objects.append(mapObject)
				}
				
				// add layer to tilemap layers
				self.objectLayers.updateValue(mapLayer, forKey: mapLayer.name)
			case "tilelayer":
				let mapLayer = TileLayer()
				mapLayer.name = layer["name"].string!.lowercaseString
				mapLayer.opacity = layer["opacity"].double!
				mapLayer.visible = layer["visible"].bool!
				mapLayer.size = CGSize(width: layer["width"].double!, height: layer["height"].double!)
				mapLayer.position = CGPoint(x: layer["x"].double!, y: layer["y"].double!)
				
				// need to convert JSON array to Int array
				// possible source of drag
				let data = layer["data"].array!
				for tile in data {
					mapLayer.tiles.append(tile.int!)
				}
				
				// add layer to tilemap layers
				self.tileLayers.updateValue(mapLayer, forKey: mapLayer.name)
			default:
				break
			}// switch type
		}// layers
		
		// Parse tilesets
		let tilesets = json["tilesets"].array!
		for tileset in tilesets {
			
			let newTileset = Tileset(
				firstGID: tileset["firstgid"].int!,
				imageName: tileset["image"].string!,
				imageSize: CGSize(width: tileset["imagewidth"].int!, height: tileset["imageheight"].int!),
				imageMargin: tileset["margin"].int!,
				imageSpacing: tileset["spacing"].int!,
				tileSize: CGSize(width: tileset["tilewidth"].int!, height: tileset["tileheight"].int!))
			
			// parse tileset properties
			
			for (gid: String, property: JSON) in tileset["tileproperties"] {
				
				// tileproperties is [String:Anyobject]
				let tileProperties = property.dictionaryObject!
				let tile = gid.toInt()!
				newTileset.tileProperties.updateValue(tileProperties, forKey: tile)
			}
			
			self.tilesets.append(newTileset)
		}
		
	}// beginParse()
	
	/// Returns layer of tiles for layer name
	func getTileLayer(named: String) -> SKNode {
		let layerMeta = self.tileLayers[named.lowercaseString]
		if !(layerMeta != nil) {
			println("Tilemap Error: no tilelayer with name \(named)")
			return SKNode()
		}
		
		let tileLayer = SKNode()
		tileLayer.name = layerMeta!.name
		tileLayer.hidden = !layerMeta!.visible
		tileLayer.alpha = CGFloat(layerMeta!.opacity)
		
		let width = Int(layerMeta!.size.width)
		let height = Int(layerMeta!.size.height)
		for row in 0..<height {
			for column in 0..<width {
				let index = column + row * width
				let gid = layerMeta!.tiles[index]
				if gid < 1 { continue }
				let tile = tileForGID(gid)
				
				tile.position = CGPoint(
					x: (CGFloat(column) * tileSize.width) - tile.size.width/2,
					y: (tileSize.height * mapSize.height) - CGFloat(row) * tileSize.height - tile.size.height/2)
				println(tile.position)
				tileLayer.addChild(tile)
			}
		}
		
		return tileLayer
	}
	
	/// Returns tile for GID value
	func tileForGID(GID: Int) -> Tile {
		let texture = tilesetTextureForGID(GID)
		let tile = Tile(texture: texture)
		
		// check for properties
		let tileset = tilesetForGID(GID)
		if let properties : [String:AnyObject] = tileset.tileProperties[GID] as? [String:AnyObject] {
			tile.properties = properties
		}
		
		return tile
	}
	
	/// Returns the tileset for a given GID
	func tilesetForGID(GID: Int) -> Tileset {
		var tileset : Tileset = self.tilesets.first!
		var highestFirstGID = 0
		for i in 0..<self.tilesets.count {
			if self.tilesets[i].firstGID > highestFirstGID && self.tilesets[i].firstGID <= GID {
				tileset = self.tilesets[i]
			}
		}
		return tileset
	}
	
	/// Returns image from tileset matching the GID
	func tilesetTextureForGID(GID: Int) -> SKTexture {
		
		// check the cache
		if let texture = tilesetTextureCache[GID] {
			return texture
		}
		
		var tileset = tilesetForGID(GID)
		
		let index = GID - tileset.firstGID
		
		let rowOffset = (((CGFloat(tileset.imageSpacing) + tileset.tileSize.height) * CGFloat(tileset.rowForIndex(index))) + CGFloat(tileset.imageMargin)) / tileset.imageSize.height
		let colOffset = (((CGFloat(tileset.imageSpacing) + tileset.tileSize.width) * CGFloat(tileset.colForIndex(index))) + CGFloat(tileset.imageMargin)) / tileset.imageSize.width
		
		let rect = CGRectMake(colOffset, rowOffset, tileset.tileSize.width/tileset.imageSize.width, tileset.tileSize.height/tileset.imageSize.height)
		
		let texture = SKTexture(rect: rect, inTexture: tileset.atlas)

		// add new texture to cache
		self.tilesetTextureCache.updateValue(texture, forKey: GID)
		
		return texture
	}
	
	/// Returns tile at location in tile units
	func tileAtPosition(inTiles tiles:CGPoint) -> Tile {
		//
		return Tile()
	}
	
	/// Returns tile at location in pixel units
	func tileAtPosition(inPixels pixels: CGPoint) -> Tile {
		//
		return Tile()
	}
	
}

/// Describes a single tile
class Tile: SKSpriteNode {
	lazy var properties : [String:AnyObject] = [String:AnyObject]()
}

/// Descripes a single object of an objectlayer. Useful for describing collision or event areas on tiles
class MapObject {
	/// Size of object. Size of (0,0) indicates a reference marker.
	var size : CGSize
	var name : String
	var visible : Bool
	var position : CGPoint
	var properties : [String : AnyObject] = [String : AnyObject]()
	
	init(size: CGSize, name: String, visible: Bool, position: CGPoint) {
		self.size = size
		self.name = name
		self.visible = visible
		self.position = position
	}
}

/// Superclass for tilemap layers
class Layer {
	/// Size of layer in tile units
	var size: CGSize = CGSizeZero
	/// Offset position of tile layer. Default (0,0)
	var position: CGPoint = CGPointZero
	var name: String = ""
	var opacity: Double = 1.0
	var visible: Bool = true
	
}

/// Describes a single tile layer
class TileLayer : Layer {
	/// Array of tile GIDs
	var tiles : [Int] = []
	
}

/// Describes a single layer of objects
class ObjectLayer : Layer {
	/// Array of layer objects
	var objects : [MapObject] = []
}

/// Describes a single tileset's properties
class Tileset {
	
	/// First non-void tile GID in set
	var firstGID : Int
	
	/// Tileset image name
	var imageName : String
	
	/// Total image size including margin and spacing
	var imageSize : CGSize
	
	/// Margin around tileset image
	var imageMargin : Int
	
	/// Spacing between tileset tile images
	var imageSpacing : Int
	
	/// Size of individual tiles in tilset
	var tileSize : CGSize
	
	/// Extra tile properties. [Int : [String:AnyObject] ]
	var tileProperties : [Int : AnyObject] = [Int : AnyObject]()
	
	/// Texture for tileset
	var atlas : SKTexture
	
	var atlasTilesPerRow : Int {
		return (Int(imageSize.width) - imageMargin * 2 + imageSpacing) / (Int(tileSize.width) + imageSpacing)
	}
	
	var atlasTilesPerCol : Int {
		return (Int(imageSize.height) - imageMargin * 2 + imageSpacing) / (Int(tileSize.height) + imageSpacing)
	}
	
	init(firstGID: Int, imageName: String, imageSize: CGSize, imageMargin: Int, imageSpacing: Int, tileSize: CGSize ) {
		
		self.firstGID = firstGID
		self.imageName = imageName
		self.imageSize = imageSize
		self.imageMargin = imageMargin
		self.imageSpacing = imageSpacing
		self.tileSize = tileSize
		
		self.atlas = SKTexture(imageNamed: self.imageName.stringByDeletingPathExtension)
	}
	
	/// Returns row in tile units for index
	func rowForIndex(index: Int) -> Int {
		return index / atlasTilesPerRow
	}
	
	/// Returns column in tile units for index
	func colForIndex(index: Int ) -> Int {
		return index % atlasTilesPerRow
	}
	
}

enum Orientation {
	case Isometric
	case Orthogonal
}




