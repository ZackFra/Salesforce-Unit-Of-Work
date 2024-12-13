public class Relationship {
        public DirtyRecord parentRecord;
        public DirtyRecord childRecord;
        
        public Relationship(DirtyRecord parentRecord, DirtyRecord childRecord) {
            this.parentRecord = parentRecord;
            this.childRecord = childRecord;
        }
}