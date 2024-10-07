package co.decodable.examples.entity.pg;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.SequenceGenerator;
import jakarta.persistence.Table;

@Entity
@Table(name="review",schema = "inventory")
public class Review extends PanacheEntityBase {
    @Id
    @GeneratedValue(generator = "review_id_seq", strategy = GenerationType.SEQUENCE)
    @SequenceGenerator(
      name = "review_id_seq", 
      sequenceName = "review_id_seq", 
      allocationSize = 50
    )
    public Integer id;
    @Column(name = "item_id")
    public String itemId; 
    @Column(name = "review_text")
    public String reviewText;
}
