module Seeds
  # Curated, fictional name pools (no Faker, no real people). Combinations are chosen by the seed's
  # fixed random generator, so the same seed always produces the same employees.
  module Names
    FIRST = %w[
      Aarav Aditi Ahmed Aisha Alex Amara Ana Anil Anna Arjun Beatriz Ben Bruno Camila Carlos Chen Chloe Clara
      Daniel Dara David Deepa Diego Elena Eli Emma Fatima Felix Fiona Gabriel Gita Hana Hari Hugo Ines Isha
      Ivan Jade James Jana Jin Julia Kabir Kavya Kofi Lara Leo Lina Luca Maya Mateo Mei Mira Nadia Neha Noah
      Nora Omar Oscar Priya Rafael Rhea Rohan Sana Sara Sofia Tariq Thea Tomas Uma Vikram Wei Yara Zane Zoe
    ].freeze

    LAST = %w[
      Abbott Alvarez Anand Bailey Banerjee Becker Bianchi Brown Carter Chandra Chopra Costa Das Dubois Evans
      Fernandez Fischer Fraser Gill Gomez Gupta Hansen Hughes Iyer Jain Jensen Joshi Kapoor Keller Khan Kim
      Kumar Larsen Lopez Mehta Meyer Mishra Moreau Murphy Nair Novak Ortiz Patel Perez Rao Reddy Rossi Roy
      Sanchez Schmidt Sharma Silva Singh Smith Sousa Taylor Tiwari Varma Verma Walsh Weiss Wilson Wong Yadav Young
    ].freeze
  end
end
