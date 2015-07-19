//
//  GameScene.swift
//  TileMap
//
//  Created by Joshua Cox on 7/2/15.
//  Copyright (c) 2015 Joshua Cox. All rights reserved.
//

import SpriteKit

class GameScene: SKScene {

	var layer = SKNode()

	override func didMoveToView(view: SKView) {

		// Model
		
		let path = "map.json"
		let tilemap = XXTileMap(fileName: path)
		
		let bglayer = tilemap.getTileLayer("background")
		bglayer.zPosition = 10
		layer.addChild(bglayer)
		
		let breakables = tilemap.getTileLayer("breakables")
		breakables.zPosition = 20
		layer.addChild(breakables)
		
		addChild(layer)
		
	}
	
	override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
		let touch = touches.first as! UITouch
		let location = touch.locationInNode(self)
		
		let offset = CGPoint(x: location.x - size.width/2, y: location.y - size.height/2)
		layer.position.x -= offset.x
		layer.position.y -= offset.y
	}
}
