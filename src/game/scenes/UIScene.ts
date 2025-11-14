import * as Phaser from 'phaser';
import { SCENE_KEYS } from './SceneKeys';

interface Slot {
    bg: Phaser.GameObjects.Image | Phaser.GameObjects.Rectangle;
    x: number;
    y: number;
    itemId?: string;
    itemImage?: Phaser.GameObjects.Image;
    countText?: Phaser.GameObjects.Text;
    icon?: Phaser.GameObjects.Image;
}

export class UIScene extends Phaser.Scene {
    #hudContainer!: Phaser.GameObjects.Container;
    #hearts!: Phaser.GameObjects.Sprite[];
    private itemBarContainer!: Phaser.GameObjects.Container;
    private slots: Slot[] = [];
    private selectedIndex: number = 0;
    private readonly SLOT_COUNT = 8;
    private barBg!: Phaser.GameObjects.Image;

    constructor() {
        super({
            key: SCENE_KEYS.UI,
            active: true
        });
    }

    public create(): void {
        // Create main HUD container with high depth
        this.#hudContainer = this.add.container(0, 0).setDepth(10000);
        this.#hearts = [];

        // Create item bar
        this.createItemBar();

        // Handle window resize with proper context binding
        this.handleResize = this.handleResize.bind(this);
        this.scale.on('resize', this.handleResize, this);
        
        // Cleanup on scene shutdown
        this.events.once('shutdown', () => {
            this.scale.off('resize', this.handleResize, this);
            this.#hudContainer.destroy(true);
        });

        // Start with UI hidden by default
        this.hideUI();
    }

    public showUI(): void {
        this.#hudContainer.setVisible(true);
    }

    public hideUI(): void {
        this.#hudContainer.setVisible(false);
    }

    private createItemBar(): void {
        // Create item bar container
        this.itemBarContainer = this.add.container(0, 0);
        this.itemBarContainer.setScrollFactor(0);
        this.itemBarContainer.setDepth(10000);
        this.#hudContainer.add(this.itemBarContainer);

        // Create slots
        this.createSlots();
        this.setupKeys();
        this.updatePosition();

        // Add test items
        this.time.delayedCall(500, () => {
            this.addItem('coin', 0);
            this.addItem('seed', 1);
        });
    }

    private createSlots(): void {
        const slotSize = 48;
        const spacing = 6;
        const totalWidth = (this.SLOT_COUNT * (slotSize + spacing)) - spacing;
        const startX = -totalWidth / 2 + slotSize / 2;

        // Add the itembar background if it exists
        if (this.textures.exists('itembar')) {
            this.barBg = this.add.image(0, 0, 'itembar').setOrigin(0.5, 0.5);
            this.itemBarContainer.add(this.barBg);
        }

        for (let i = 0; i < this.SLOT_COUNT; i++) {
            const x = startX + i * (slotSize + spacing);

            // Create slot background
            let slotBg;
            if (this.textures.exists('slot')) {
                slotBg = this.add.image(x, 0, 'slot').setOrigin(0.5, 0.5);
            } else {
                // Create an invisible slot for layout purposes
                slotBg = this.add.rectangle(x, 0, slotSize, slotSize, 0x000000, 0)
                    .setOrigin(0.5, 0.5);
            }

            // Add slot number
            const numText = this.add.text(x, -20, `${i + 1}`, {
                fontSize: '14px',
                color: '#ffffff',
                stroke: '#000000',
                strokeThickness: 3
            }).setOrigin(0.5, 0.5);

            this.itemBarContainer.add(slotBg);
            this.itemBarContainer.add(numText);

            this.slots.push({
                bg: slotBg,
                x: x,
                y: 0
            });
        }
    }

    private setupKeys(): void {
        // Add keyboard controls for slot selection (1-8)
        for (let i = 0; i < this.SLOT_COUNT; i++) {
            const key = this.input.keyboard?.addKey(Phaser.Input.Keyboard.KeyCodes[i + 49]); // 49 is keycode for '1'
            key?.on('down', () => {
                this.selectedIndex = i;
                this.updateSelection();
            });
        }
    }

    private updateSelection(): void {
        this.slots.forEach((slot, i) => {
            const tint = i === this.selectedIndex ? 0x88ff88 : 0xffffff;
            if ('setTint' in slot.bg) {
                slot.bg.setTint(tint);
            }
            if (slot.icon) {
                slot.icon.setTint(tint);
            }
        });
    }

    public addItem(itemId: string, slotIndex: number): void {
        if (slotIndex < 0 || slotIndex >= this.SLOT_COUNT) {
            console.warn(`Invalid slot index: ${slotIndex}`);
            return;
        }

        const slot = this.slots[slotIndex];

        // Remove existing item if any
        if (slot.itemImage) {
            slot.itemImage.destroy();
        }
        if (slot.countText) {
            slot.countText.destroy();
        }

        // Add item image
        if (this.textures.exists(itemId)) {
            slot.itemImage = this.add.image(slot.x, slot.y, itemId)
                .setDisplaySize(32, 32)
                .setOrigin(0.5, 0.5);
            this.itemBarContainer.add(slot.itemImage);
        }

        // Add item count (example)
        slot.countText = this.add.text(slot.x + 10, slot.y + 10, '1', {
            fontSize: '14px',
            color: '#ffffff',
            backgroundColor: 'rgba(0,0,0,0.7)',
            padding: { x: 2, y: 1 }
        }).setOrigin(1, 1);
        this.itemBarContainer.add(slot.countText);

        slot.itemId = itemId;
        this.updateSelection();
    }

    private updatePosition(): void {
        const x = this.cameras.main.centerX;
        const y = this.cameras.main.height - 60; // Position at bottom of screen
        this.itemBarContainer.setPosition(x, y);
    }

    private handleResize = (): void => {
        this.updatePosition();
    }
}