-- Optional. The resource creates these tables on start when oxmysql is running.
-- Import this yourself only if you want the schema in place before the first boot.

CREATE TABLE IF NOT EXISTS `djerp_favorites` (
    `identifier` VARCHAR(80) NOT NULL,
    `emote_key` VARCHAR(48) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`, `emote_key`)
);

CREATE TABLE IF NOT EXISTS `djerp_recent` (
    `identifier` VARCHAR(80) NOT NULL,
    `emote_key` VARCHAR(48) NOT NULL,
    `used_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`, `emote_key`)
);

CREATE TABLE IF NOT EXISTS `djerp_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `action` VARCHAR(32) NOT NULL,
    `actor_id` INT NULL,
    `actor_name` VARCHAR(128) NULL,
    `actor_identifier` VARCHAR(80) NULL,
    `target_id` INT NULL,
    `target_name` VARCHAR(128) NULL,
    `target_identifier` VARCHAR(80) NULL,
    `emote_key` VARCHAR(48) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_djerp_logs_created` (`created_at`)
);
