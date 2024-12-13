/**
 * @description A registered parent and child record
 * @author Zackary Frazier
 * @since 12/13/2024
 */
public class Relationship {
        public DirtyRecord parentRecord;
        public DirtyRecord childRecord;
        
        /**
         * @description constructor
         * @param parentRecord `DirtyRecord`
         * @param childRecord `DirtyRecord`
         */
        public Relationship(DirtyRecord parentRecord, DirtyRecord childRecord) {
            this.parentRecord = parentRecord;
            this.childRecord = childRecord;
        }
}