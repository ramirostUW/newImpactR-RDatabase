CREATE TABLE Discourse (
  discourse_id int(11) NOT NULL AUTO_INCREMENT,
  content text,
  source_id int(11) DEFAULT NULL,
  region varchar(255) DEFAULT NULL,
  country_code varchar(3) DEFAULT NULL,
  created_time date DEFAULT NULL,
  imported_time date DEFAULT NULL,
  secondary_content text,
  isPost tinyint(1) DEFAULT NULL,
  post_id int(11) DEFAULT NULL,
  ori_id varchar(255) DEFAULT NULL,
  url text,
  PRIMARY KEY (discourse_id),
  UNIQUE KEY ori_id (ori_id),
  KEY source_id (source_id),
  KEY region (region),
  KEY created_time (created_time),
  KEY id_date (created_time,discourse_id),
  KEY region_date (created_time,region),
  KEY id_region_date (discourse_id,region,created_time),
  CONSTRAINT Discourse_ibfk_1 FOREIGN KEY (source_id) REFERENCES Source (source_id),
  CONSTRAINT region FOREIGN KEY (region) REFERENCES Regions (region)
 );
  
CREATE TABLE Regions (
  region varchar(255) NOT NULL,
  parent_region varchar(255) DEFAULT NULL,
  level int(11) DEFAULT NULL,
  is_active tinyint(1) DEFAULT NULL,
  PRIMARY KEY (region),
  KEY fkey (parent_region),
  KEY region_parent (region,parent_region),
  CONSTRAINT fkey FOREIGN KEY (parent_region) REFERENCES Regions (region)
);

CREATE TABLE Platform (
  platform_name varchar(255) NOT NULL DEFAULT '',
  platform_type varchar(255) DEFAULT NULL,
  PRIMARY KEY (platform_name)
);

CREATE TABLE Source (
  source_id int(11) NOT NULL AUTO_INCREMENT,
  source_desc varchar(255) DEFAULT NULL,
  is_survey tinyint(1) DEFAULT NULL,
  region varchar(255) DEFAULT NULL,
  platform_name varchar(255) DEFAULT NULL,
  share_parent tinyint(1) DEFAULT NULL,
  share_child tinyint(1) DEFAULT NULL,
  scrape tinyint(1) DEFAULT NULL,
  PRIMARY KEY (source_id),
  KEY platform_name (platform_name),
  CONSTRAINT Source_ibfk_1 FOREIGN KEY (platform_name) REFERENCES Platform (platform_name)
);

CREATE TABLE ModelVersion (
  model_id int(11) NOT NULL,
  model_task varchar(255) DEFAULT NULL,
  created_time date DEFAULT NULL,
  PRIMARY KEY (model_id)
);

CREATE TABLE DiscourseHashtags (
  discourse_id int(11) DEFAULT NULL,
  hashtag varchar(255) DEFAULT NULL,
  KEY discourse_id (discourse_id),
  CONSTRAINT DiscourseHashtags_ibfk_1 FOREIGN KEY (discourse_id) REFERENCES Discourse (discourse_id)
);

CREATE TABLE DiscourseSentiment (
  discourse_id int(11) DEFAULT NULL,
  sentiment int(11) DEFAULT NULL,
  positive_prob float DEFAULT NULL,
  netural_prob float DEFAULT NULL,
  negative_prob float DEFAULT NULL,
  model_id int(11) DEFAULT NULL,
  UNIQUE KEY discourse_id (discourse_id,sentiment),
  UNIQUE KEY discourse_id_2 (discourse_id),
  KEY model_id (model_id),
  KEY sentiment (sentiment),
  KEY id_sentiment (discourse_id,sentiment),
  CONSTRAINT DiscourseSentiment_ibfk_1 FOREIGN KEY (discourse_id) REFERENCES Discourse (discourse_id),
  CONSTRAINT DiscourseSentiment_ibfk_2 FOREIGN KEY (model_id) REFERENCES ModelVersion (model_id),
  CONSTRAINT fk_sentiment FOREIGN KEY (discourse_id) REFERENCES Discourse (discourse_id)
);

CREATE TABLE DiscourseType (
  discourse_id int(11) DEFAULT NULL,
  type varchar(255) DEFAULT NULL,
  confidence float DEFAULT NULL,
  model_id int(11) DEFAULT NULL,
  UNIQUE KEY discourse_id (discourse_id),
  KEY model_id (model_id),
  CONSTRAINT DiscourseType_ibfk_1 FOREIGN KEY (discourse_id) REFERENCES Discourse (discourse_id),
  CONSTRAINT DiscourseType_ibfk_2 FOREIGN KEY (model_id) REFERENCES ModelVersion (model_id)
)

 CREATE TABLE TrendingTopics (
  topic varchar(255) NOT NULL DEFAULT '',
  counts int(11) DEFAULT NULL,
  n_gram int(11) DEFAULT NULL,
  created_time date DEFAULT NULL,
  KEY topic_time (topic,created_time)
);

CREATE TABLE DiscourseTopicGraph (
  discourse_id int(11) DEFAULT NULL,
  topic varchar(255) DEFAULT NULL,
  KEY topic (topic),
  KEY id_topic (discourse_id,topic),
  CONSTRAINT DiscourseTopicGraph_ibfk_1 FOREIGN KEY (discourse_id) REFERENCES Discourse (discourse_id),
  CONSTRAINT fk FOREIGN KEY (discourse_id) REFERENCES Discourse (discourse_id)
);

CREATE TABLE ImpactArea (
  impact_area_id int(11) NOT NULL,
  tag varchar(255) DEFAULT NULL,
  source_parent_id int(11) DEFAULT NULL,
  impact_parent_id int(11) DEFAULT NULL,
  source_ontology varchar(255) DEFAULT NULL,
  PRIMARY KEY (impact_area_id),
  KEY tag (tag),
  KEY Ia_so (impact_area_id,source_ontology),
  KEY Ia_tag (impact_area_id,tag)
);

CREATE TABLE DiscourseImpactArea (
  discourse_id int(11) DEFAULT NULL,
  impact_area_id int(11) DEFAULT NULL,
  model_id int(11) DEFAULT NULL,
  UNIQUE KEY discourse_id (discourse_id,impact_area_id),
  KEY impact_area_id (impact_area_id),
  KEY model_id (model_id),
  CONSTRAINT DiscourseImpactArea_ibfk_1 FOREIGN KEY (discourse_id) REFERENCES Discourse (discourse_id),
  CONSTRAINT DiscourseImpactArea_ibfk_2 FOREIGN KEY (impact_area_id) REFERENCES ImpactArea (impact_area_id),
  CONSTRAINT DiscourseImpactArea_ibfk_3 FOREIGN KEY (model_id) REFERENCES ModelVersion (model_id)
);

