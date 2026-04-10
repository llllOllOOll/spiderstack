-- migrate:up

CREATE TABLE IF NOT EXISTS games (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    platform TEXT NOT NULL,
    release_year INTEGER NOT NULL,
    genre TEXT NOT NULL,
    developer TEXT NOT NULL,
    sales_millions NUMERIC(5,2) DEFAULT 0,
    rating NUMERIC(3,1) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_games_platform ON games(platform);
CREATE INDEX IF NOT EXISTS idx_games_release_year ON games(release_year);
CREATE INDEX IF NOT EXISTS idx_games_genre ON games(genre);

-- Insert 50 classic games
INSERT INTO games (name, platform, release_year, genre, developer, sales_millions, rating) VALUES
('Super Mario Bros.', 'NES', 1985, 'Platformer', 'Nintendo', 40.12, 9.5),
('Tetris', 'NES', 1989, 'Puzzle', 'Nintendo', 30.26, 9.7),
('Minecraft', 'Multi', 2011, 'Sandbox', 'Mojang', 300.00, 9.5),
('Grand Theft Auto V', 'Multi', 2013, 'Action', 'Rockstar', 185.00, 9.5),
('Wii Sports', 'Wii', 2006, 'Sports', 'Nintendo', 82.90, 9.0),
('PUBG: Battlegrounds', 'Multi', 2017, 'Battle Royale', 'Krafton', 75.00, 9.0),
('Mario Kart Wii', 'Wii', 2008, 'Racing', 'Nintendo', 37.38, 9.2),
('Madden NFL 2004', 'Multi', 2003, 'Sports', 'EA Sports', 31.00, 9.0),
('Wii Fit', 'Wii', 2007, 'Simulation', 'Nintendo', 43.80, 9.0),
('Wii Play', 'Wii', 2006, 'Casual', 'Nintendo', 29.00, 9.0),
('Pokemon Red/Green/Blue', 'GB', 1996, 'RPG', 'Nintendo', 31.12, 9.5),
('Tetris (EA)', 'GB', 1989, 'Puzzle', 'Nintendo', 8.00, 9.0),
('GTA San Andreas', 'Multi', 2004, 'Action', 'Rockstar', 27.50, 9.4),
('Call of Duty: Modern Warfare 3', 'Multi', 2011, 'FPS', 'Activision', 26.00, 9.0),
('FIFA 16', 'Multi', 2015, 'Sports', 'EA Sports', 26.00, 9.0),
('Borderlands 2', 'Multi', 2012, 'FPS', '2K Games', 26.00, 9.1),
('Grand Theft Auto IV', 'Multi', 2008, 'Action', 'Rockstar', 25.00, 9.5),
('Halo: The Master Chief Collection', 'Xbox', 2014, 'FPS', 'Microsoft', 24.00, 9.3),
('Mario Kart 8', 'Switch', 2014, 'Racing', 'Nintendo', 24.00, 9.5),
('Sonic the Hedgehog', 'Mega Drive', 1991, 'Platformer', 'Sega', 24.00, 9.2),
('Pokemon Gold/Silver', 'GB', 1999, 'RPG', 'Nintendo', 23.65, 9.5),
('Super Smash Bros. Ultimate', 'Switch', 2018, 'Fighting', 'Nintendo', 23.00, 9.5),
('Call of Duty: Black Ops', 'Multi', 2010, 'FPS', 'Activision', 23.00, 9.0),
('Battlefield 3', 'Multi', 2011, 'FPS', 'EA', 22.00, 9.0),
('Just Dance 2021', 'Multi', 2020, 'Casual', 'Ubisoft', 21.00, 9.0),
('Warcraft III', 'PC', 2002, 'RTS', 'Blizzard', 20.00, 9.3),
('Pokemon Ruby/Sapphire', 'GBA', 2002, 'RPG', 'Nintendo', 19.00, 9.3),
('GTA V (Xbox 360)', 'Xbox 360', 2013, 'Action', 'Rockstar', 19.00, 9.5),
('The Legend of Zelda', 'NES', 1986, 'Adventure', 'Nintendo', 18.50, 9.5),
('The Sims', 'PC', 2000, 'Simulation', 'EA', 17.50, 9.3),
('Super Mario World', 'SNES', 1990, 'Platformer', 'Nintendo', 17.00, 9.6),
('Pokemon Diamond/Pearl', 'DS', 2006, 'RPG', 'Nintendo', 17.00, 9.2),
('Call of Duty: Black Ops II', 'Multi', 2012, 'FPS', 'Activision', 16.50, 9.0),
('The Elder Scrolls V: Skyrim', 'Multi', 2011, 'RPG', 'Bethesda', 16.00, 9.5),
('GTA Vice City', 'Multi', 2002, 'Action', 'Rockstar', 15.50, 9.5),
('Pokemon Black/White', 'DS', 2010, 'RPG', 'Nintendo', 15.40, 9.1),
('Just Dance 2015', 'Multi', 2014, 'Casual', 'Ubisoft', 15.00, 9.0),
('Super Mario 64', 'N64', 1996, 'Platformer', 'Nintendo', 15.00, 9.7),
('Call of Duty 4: Modern Warfare', 'Multi', 2007, 'FPS', 'Activision', 15.00, 9.5),
('Crash Bandicoot', 'PlayStation', 1996, 'Platformer', 'Sony', 14.50, 9.3),
('FIFA 07', 'Multi', 2006, 'Sports', 'EA Sports', 14.50, 9.0),
('Pokemon HeartGold/SoulSilver', 'DS', 2009, 'RPG', 'Nintendo', 14.00, 9.4),
('GTA III', 'Multi', 2001, 'Action', 'Rockstar', 13.50, 9.2),
('Resident Evil 5', 'Multi', 2009, 'Survival Horror', 'Capcon', 13.00, 9.0),
('New Super Mario Bros. Wii', 'Wii', 2009, 'Platformer', 'Nintendo', 13.00, 9.2),
('The Last of Us', 'PlayStation 3', 2013, 'Action', 'Sony', 12.50, 9.5),
('Final Fantasy VII', 'PlayStation', 1997, 'RPG', 'Square', 12.30, 9.6),
('Pokemon X/Y', '3DS', 2013, 'RPG', 'Nintendo', 12.00, 9.3),
('Donkey Kong Country', 'SNES', 1994, 'Platformer', 'Nintendo', 12.00, 9.4),
('GTA IV (Xbox 360)', 'Xbox 360', 2008, 'Action', 'Rockstar', 11.50, 9.5),
('Pokemon FireRed/LeafGreen', 'GBA', 2004, 'RPG', 'Nintendo', 11.50, 9.3);

-- migrate:down
DROP TABLE IF EXISTS games;