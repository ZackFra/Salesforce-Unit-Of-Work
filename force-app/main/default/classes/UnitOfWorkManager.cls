/**
 * @description Global Singleton class to manage the lifecycle of the UnitOfWork.
 * Ensures only one instance of the Unit of Work is created per transaction and makes it
 * accessible across all packages.
 */
@namespaceAccessible
public with sharing class UnitOfWorkManager {

    // The registry map, uses the Config object as its key.
    @TestVisible
    private static Map<Config, UnitOfWork> uowRegistry = 
        new Map<Config, UnitOfWork>();

    private UnitOfWorkManager() {}

    /**
     * @description Gets a Unit of Work that matches the specified configuration.
     * The unit of work config, is allOrNothing True and Running in User mode.
     * @return The requested UnitOfWork instance.
     */
    @namespaceAccessible
    public static UnitOfWork getUnitOfWork() {
        Config config = new Config(true, AccessLevel.USER_MODE);
        return getUnitOfWork(config);
    }

    /**
     * @description Gets a Unit of Work that matches the specified configuration.
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return The requested UnitOfWork instance.
     */
    @namespaceAccessible
    public static UnitOfWork getUnitOfWork(Boolean allOrNone, AccessLevel accessLevel) {
        Config config = new Config(allOrNone, accessLevel);
        return getUnitOfWork(config);
    }

    /**
     * @description Gets a Unit of Work that matches the specified configuration.
     * @param allOrNone `Boolean`
     * Default User Mode access level is set.
     * @return The requested UnitOfWork instance.
     */
    @namespaceAccessible
    public static UnitOfWork getUnitOfWork(Boolean allOrNone) {
        Config config = new Config(allOrNone, AccessLevel.USER_MODE);
        return getUnitOfWork(config);
    }

    /**
     * @description Gets a Unit of Work that matches the specified configuration.
     * @param access `AccessLevel`
     * Default AllOrNothing is set True.
     * @return The requested UnitOfWork instance.
     */
    @namespaceAccessible
    public static UnitOfWork getUnitOfWork(AccessLevel accessLevel) {
        Config config = new Config(true, accessLevel);
        return getUnitOfWork(config);
    }

    /**
     * @description Gets a Unit of Work that matches the specified configuration.
     * @param  config A Config object detailing the required UoW.
     * @return The requested UnitOfWork instance.
     */
    private static UnitOfWork getUnitOfWork(Config config) {
        if (!uowRegistry.containsKey(config)) {
            uowRegistry.put(config, createUnitOfWork(config));
        }
        return uowRegistry.get(config);
    }

    /**
     * @description Factory method to construct the correct UoW instance based on the config.
     */
    private static UnitOfWork createUnitOfWork(Config config) {
        return new UnitOfWork(config.allOrNone, config.AccessLevel);
    }
    
    /**
     * @description Commits all registered Unit of Work instances in a controlled order.
     */
    @namespaceAccessible
    public static void commitWork() {
        if (uowRegistry.isEmpty()) {
            return;
        }

        // Separate the keys (Config objects) by commit variant to control order
        List<Config> standardConfigs = new List<Config>();
        List<Config> partialConfigs = new List<Config>();

        for(Config cfg : uowRegistry.keySet()){
            if(cfg.allOrNone == true) {
                standardConfigs.add(cfg);
            } else {
                partialConfigs.add(cfg);
            }
        }

        // Commit all-or-nothing UoWs first for maximum safety
        for(Config cfg : standardConfigs){
            uowRegistry.get(cfg).commitWork();
        }

        // Then commit partial-success UoWs
        for(Config cfg : partialConfigs){
            uowRegistry.get(cfg).commitWork();
        }
    }


    /**
     * @description Configuration object to define the characteristics of a requested Unit of Work.
     * This object is used as the key in the UoW registry.
    */
    public class Config {
        private Boolean allOrNone { get; private set; }
        private AccessLevel accessLevel { get; private set; }

        public Config(Boolean allOrNone, AccessLevel accessLevel) {
            this.allOrNone = allOrNone;
            this.accessLevel = accessLevel;
        }

        // --- IMPORTANT: Required for using this object as a Map key ---
        public Boolean equals(Object obj) {
            if (obj == null || !(obj instanceof Config)) {
                return false;
            }
            Config other = (Config) obj;
            return this.allOrNone == other.allOrNone && this.accessLevel == other.accessLevel;
        }

        public Integer hashCode() {
            // A common way to generate a hash code from multiple fields.
            return System.hashCode(this.allOrNone) * 31 + System.hashCode(this.accessLevel);
        }
    }
}